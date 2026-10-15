import 'package:eho/core/config.dart';
import 'package:eho/core/firebase/firebase_init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('realFirebaseOptions', () {
    test('missing required values name every missing define', () {
      expect(
        () => realFirebaseOptions(const FirebaseWebConfig()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('FIREBASE_API_KEY'),
              contains('FIREBASE_APP_ID'),
              contains('FIREBASE_PROJECT_ID'),
            ),
          ),
        ),
      );
      expect(
        () => realFirebaseOptions(
          const FirebaseWebConfig(apiKey: 'k', appId: 'a'),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('FIREBASE_PROJECT_ID'), isNot(contains('API_KEY'))),
          ),
        ),
      );
    });

    test('full values map to the options fields', () {
      final o = realFirebaseOptions(
        const FirebaseWebConfig(
          apiKey: 'key',
          appId: '1:1:web:1',
          projectId: 'demo-x',
          messagingSenderId: '123',
          authDomain: 'demo-x.firebaseapp.com',
          storageBucket: 'demo-x.firebasestorage.app',
        ),
      );
      expect(o.apiKey, 'key');
      expect(o.appId, '1:1:web:1');
      expect(o.projectId, 'demo-x');
      expect(o.messagingSenderId, '123');
      expect(o.authDomain, 'demo-x.firebaseapp.com');
      expect(o.storageBucket, 'demo-x.firebasestorage.app');
    });

    test('optional values may be left out', () {
      final o = realFirebaseOptions(
        const FirebaseWebConfig(apiKey: 'k', appId: 'a', projectId: 'p'),
      );
      expect(o.authDomain, isNull);
      expect(o.storageBucket, isNull);
      expect(o.messagingSenderId, '');
    });
  });

  test('default environment keeps emulators on and Firebase config empty', () {
    final c = AppConfig.fromEnvironment();
    expect(c.useEmulators, isTrue);
    expect(c.firebase.apiKey, isEmpty);
    expect(c.firebase.projectId, isEmpty);
  });
}
