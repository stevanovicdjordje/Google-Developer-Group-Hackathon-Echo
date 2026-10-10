import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/published_map_repository.dart';
import '../editor/editor_providers.dart';
import '../model/route_models.dart';

/// Ensures a signed-in user (attendees: anonymous) before reading Firestore.
/// Fails after [_signInTimeout] instead of retrying, so the viewer can show
/// "server unavailable" with a retry button. Overridden in tests.
final mapsSignedInProvider = FutureProvider<String>((ref) async {
  final auth = FirebaseAuth.instance;
  Future<String> signIn() async {
    // On web the persisted user is restored asynchronously; wait for it first.
    final restored = await auth.authStateChanges().first;
    final user = restored ?? (await auth.signInAnonymously()).user!;
    return user.uid;
  }

  return signIn().timeout(_signInTimeout);
}, retry: (_, _) => null);

const _signInTimeout = Duration(seconds: 10);

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

/// Walking route for the viewer. Errors (`no_route`, offline) are shown
/// once, without retrying.
final mapsRouteProvider = FutureProvider.autoDispose
    .family<MapRoute, RouteQuery>((ref, q) async {
      await ref.watch(mapsSignedInProvider.future);
      return ref
          .watch(mapsApiProvider)
          .getRoute(
            q.eventId,
            from: q.from,
            to: q.to,
            accessible: q.accessible,
          );
    }, retry: (_, _) => null);
