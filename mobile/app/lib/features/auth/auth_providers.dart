import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Current Firebase user; attendees are signed in anonymously on first use.
final currentUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Signs in anonymously when nobody is signed in. Returns the user's uid.
final ensureSignedInProvider = FutureProvider<String>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
  return user.uid;
});
