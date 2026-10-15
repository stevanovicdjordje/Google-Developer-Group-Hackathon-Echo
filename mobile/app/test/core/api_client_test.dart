import 'dart:convert';

import 'package:eho/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient client(MockClientHandler handler, {String? token}) => ApiClient(
    baseUrl: 'http://api.test',
    tokenProvider: () async => token,
    httpClient: MockClient(handler),
  );

  test('healthz succeeds on 200', () async {
    final c = client((req) async {
      expect(req.url.toString(), 'http://api.test/healthz');
      expect(req.headers.containsKey('Authorization'), isFalse);
      return http.Response('{"status":"ok"}', 200);
    });
    await c.healthz();
  });

  test('error body is parsed into ApiException', () async {
    final c = client(
      (req) async => http.Response(
        jsonEncode({
          'code': 'not_found',
          'message': 'nope',
          'details': {'id': 'x'},
        }),
        404,
      ),
    );
    await expectLater(
      c.healthz(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.code, 'code', 'not_found')
            .having((e) => e.details, 'details', {'id': 'x'}),
      ),
    );
  });

  test('network failure becomes a network ApiException', () async {
    final c = client((req) async => throw http.ClientException('offline'));
    await expectLater(
      c.healthz(),
      throwsA(
        isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true),
      ),
    );
  });
}
