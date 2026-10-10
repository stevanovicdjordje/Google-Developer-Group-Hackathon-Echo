import 'dart:convert';
import 'dart:io';

import 'package:eho_maps/src/editor/maps_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fixture from the shared contract examples.
String example(String name) =>
    File('../../contracts/maps/examples/$name').readAsStringSync();

MapsApi api(MockClientHandler handler) => MapsApi(
  baseUrl: 'http://api',
  tokenProvider: () async => 'tok',
  httpClient: MockClient(handler),
);

void main() {
  test('sends the bearer token and parses a publish', () async {
    late http.Request seen;
    final r = await api((req) async {
      seen = req;
      return http.Response(example('publish.response.json'), 200);
    }).publish('e1');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/v1/events/e1/publish');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(r.ok, isTrue);
    expect(r.version, 3);
    expect(r.warnings.single.code, 'no_entrance');
  });

  test('a blocked publish is a result, not an exception', () async {
    final r = await api(
      (_) async => http.Response(
        jsonEncode({
          'code': 'publish_blocked',
          'message': 'map has errors',
          'details': {
            'errors': [
              {'code': 'no_floors', 'message': 'no floors'},
            ],
            'warnings': <Object>[],
          },
        }),
        422,
      ),
    ).publish('e1');
    expect(r.ok, isFalse);
    expect(r.errors.single.code, 'no_floors');
  });

  test('validation errors carry field messages', () async {
    final call = api(
      (_) async =>
          http.Response(example('validation-error.response.json'), 422),
    ).createFeature('e1', {});
    await expectLater(
      call,
      throwsA(
        isA<MapsApiException>()
            .having((e) => e.code, 'code', 'validation_failed')
            .having((e) => e.fieldErrors, 'fieldErrors', isNotEmpty),
      ),
    );
  });

  test('network failures map to code "network"', () async {
    final call = api((_) async => throw http.ClientException('refused'))
        .listMyEvents();
    await expectLater(
      call,
      throwsA(isA<MapsApiException>().having((e) => e.isNetwork, 'net', true)),
    );
  });
}
