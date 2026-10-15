import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Deletes the Firebase Auth session the JS SDK persisted in the browser.
///
/// On web, FlutterFire creates Auth (and restores a saved user) inside
/// `Firebase.initializeApp`, before `useAuthEmulator` runs. Restoring a user
/// left over from an earlier emulator session calls the real Google endpoint
/// ("api-key-not-valid"), after which connecting the emulator fails silently
/// and every later sign-in goes to production. Starting without a saved user
/// avoids that; anonymous attendees just get a fresh uid per page load.
Future<void> clearPersistedAuthSession() async {
  final storage = web.window.localStorage;
  for (var i = storage.length - 1; i >= 0; i--) {
    final key = storage.key(i);
    if (key != null && key.startsWith('firebase:')) storage.removeItem(key);
  }

  final done = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase('firebaseLocalStorageDb');
  void finish(web.Event _) {
    if (!done.isCompleted) done.complete();
  }

  request.onsuccess = finish.toJS;
  request.onerror = finish.toJS;
  request.onblocked = finish.toJS;
  await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
}
