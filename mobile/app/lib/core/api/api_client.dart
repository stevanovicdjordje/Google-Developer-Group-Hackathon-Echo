import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error returned by the backend in the uniform `{code, message, details}` format,
/// or a client-side failure (`network`, `timeout`, `bad_response`).
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message, [this.details]);

  final int statusCode;
  final String code;
  final String message;
  final Object? details;

  bool get isNetwork => code == 'network' || code == 'timeout';

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Returns the current Firebase ID token, or null when signed out.
typedef TokenProvider = Future<String?> Function();

/// Thin HTTP client for the Eho API (`contracts/openapi.yaml`).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenProvider tokenProvider;
  final Duration timeout;
  final http.Client _http;

  Future<void> healthz() async {
    await _send('GET', '/healthz', auth: false);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    if (auth) {
      final token = await tokenProvider();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'timeout', 'request timed out');
    } on http.ClientException catch (e) {
      throw ApiException(0, 'network', e.message);
    }

    final decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map<String, Object?>) {
      throw ApiException(
        response.statusCode,
        decoded['code'] as String? ?? 'unknown',
        decoded['message'] as String? ?? 'request failed',
        decoded['details'],
      );
    }
    throw ApiException(response.statusCode, 'unknown', 'request failed');
  }

  Object? _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw ApiException(response.statusCode, 'bad_response', 'invalid JSON');
    }
  }
}
