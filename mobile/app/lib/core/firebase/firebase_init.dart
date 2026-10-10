import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config.dart';
import 'clear_auth_session_stub.dart'
    if (dart.library.js_interop) 'clear_auth_session_web.dart';

/// Options for the local `demo-eho` emulator project. Not secrets: demo
/// projects only work against the emulators. A real project is configured
/// later with `flutterfire configure`.
const _demoOptions = FirebaseOptions(
  apiKey: 'demo-api-key',
  appId: '1:000000000000:web:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'demo-eho',
  storageBucket: 'demo-eho.appspot.com',
);

// Ports must match backend/firebase/firebase.json.
const _authPort = 9099;
const _firestorePort = 8081;
const _storagePort = 9199;

Future<void> initFirebase(AppConfig config) async {
  if (!config.useEmulators) {
    throw UnsupportedError(
      'No real Firebase project configured yet: run with USE_EMULATORS=true.',
    );
  }
  await clearPersistedAuthSession();
  await Firebase.initializeApp(options: _demoOptions);
  final host = config.emulatorHost;
  await FirebaseAuth.instance.useAuthEmulator(host, _authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(host, _firestorePort);
  await FirebaseStorage.instance.useStorageEmulator(host, _storagePort);
}
