import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'clear_auth_session_stub.dart'
    if (dart.library.js_interop) 'clear_auth_session_web.dart';

/// Options for the local `demo-eho` emulator project. Not secrets: demo
/// projects only work against the emulators. A real project is configured
/// with `--dart-define=FIREBASE_*` (see [realFirebaseOptions]).
///
/// The native iOS SDK validates the option formats at startup and aborts on
/// a web app id or a short API key, so iOS gets correctly shaped (still fake)
/// values; the emulators accept anything.
FirebaseOptions get _demoOptions => FirebaseOptions(
  apiKey: _isIOS ? 'Ademo-key-for-local-emulators-only00000' : 'demo-api-key',
  appId: _isIOS
      ? '1:000000000000:ios:0000000000000000000000'
      : '1:000000000000:web:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-eho',
  storageBucket: 'demo-eho.appspot.com',
  iosBundleId: 'rs.eho.eho',
);

bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

// Ports must match backend/firebase/firebase.json.
const _authPort = 9099;
const _firestorePort = 8081;
const _storagePort = 9199;

/// Builds [FirebaseOptions] for a real project from the `FIREBASE_*` defines.
/// Throws a [StateError] naming every missing required define
/// (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`). The sender
/// id, auth domain and storage bucket are optional.
FirebaseOptions realFirebaseOptions(FirebaseWebConfig c) {
  final missing = [
    if (c.apiKey.isEmpty) 'FIREBASE_API_KEY',
    if (c.appId.isEmpty) 'FIREBASE_APP_ID',
    if (c.projectId.isEmpty) 'FIREBASE_PROJECT_ID',
  ];
  if (missing.isNotEmpty) {
    throw StateError(
      'USE_EMULATORS=false needs a real Firebase project. Missing '
      '--dart-define: ${missing.join(', ')}.',
    );
  }
  return FirebaseOptions(
    apiKey: c.apiKey,
    appId: c.appId,
    messagingSenderId: c.messagingSenderId,
    projectId: c.projectId,
    authDomain: c.authDomain.isEmpty ? null : c.authDomain,
    storageBucket: c.storageBucket.isEmpty ? null : c.storageBucket,
  );
}

Future<void> initFirebase(AppConfig config) async {
  if (!config.useEmulators) {
    await Firebase.initializeApp(options: realFirebaseOptions(config.firebase));
    return;
  }
  await clearPersistedAuthSession();
  await Firebase.initializeApp(options: _demoOptions);
  final host = config.emulatorHost;
  await FirebaseAuth.instance.useAuthEmulator(host, _authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(host, _firestorePort);
  await FirebaseStorage.instance.useStorageEmulator(host, _storagePort);
}
