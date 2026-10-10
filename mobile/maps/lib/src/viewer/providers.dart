import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/published_map_repository.dart';

/// Ensures a signed-in user (attendees: anonymous) before reading Firestore.
/// Overridden in tests.
final mapsSignedInProvider = FutureProvider<String>((ref) async {
  final auth = FirebaseAuth.instance;
  debugPrint('[maps] waiting for auth state');
  // On web the persisted user is restored asynchronously; wait for it first.
  final restored = await auth.authStateChanges().first;
  debugPrint('[maps] auth state: ${restored?.uid}');
  User user;
  try {
    user = restored ?? (await auth.signInAnonymously()).user!;
  } catch (e, st) {
    debugPrint('[maps] sign-in failed: $e\n$st');
    rethrow;
  }
  debugPrint('[maps] signed in: ${user.uid}');
  return user.uid;
});

final publishedMapRepositoryProvider = Provider<PublishedMapRepository>(
  (ref) => FirestorePublishedMapRepository(),
);

/// Live published map of an event.
final publishedEventProvider = StreamProvider.autoDispose
    .family<PublishedEvent, String>(
      (ref, eventId) async* {
        await ref.watch(mapsSignedInProvider.future);
        yield* ref.watch(publishedMapRepositoryProvider).watch(eventId);
      },
      // Not-found and offline are shown to the user with a retry button instead.
      retry: (_, _) => null,
    );

final floorImageUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(publishedMapRepositoryProvider).imageUrl(path),
);
