import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../model/map_models.dart';

/// The attendee's view of an event: its name and the published map.
class PublishedEvent {
  const PublishedEvent({
    required this.id,
    required this.name,
    required this.map,
  });

  final String id;
  final String name;
  final VenueMap map;
}

/// The event does not exist or is not published (or the caller may not see it).
class EventNotFound implements Exception {
  const EventNotFound();
}

/// No data arrived in time (offline / backend unreachable).
class MapUnavailable implements Exception {
  const MapUnavailable();
}

/// Read-only access to published map data (`contracts/maps/realtime.md`).
abstract interface class PublishedMapRepository {
  /// Emits the event and its published map, and again on every publish.
  Stream<PublishedEvent> watch(String eventId);

  /// Download URL of a floor-plan image in Storage.
  Future<String> imageUrl(String path);
}

/// Firestore snapshot listeners on `events/{id}` and `published/map/**`.
class FirestorePublishedMapRepository implements PublishedMapRepository {
  FirestorePublishedMapRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    this.firstDataTimeout = const Duration(seconds: 15),
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final Duration firstDataTimeout;

  @override
  Future<String> imageUrl(String path) => _storage.ref(path).getDownloadURL();

  @override
  Stream<PublishedEvent> watch(String eventId) {
    final event = _db.collection('events').doc(eventId);
    final map = event.collection('published').doc('map');

    late final StreamController<PublishedEvent> out;
    final subs = <StreamSubscription<Object?>>[];
    DocumentSnapshot<Map<String, dynamic>>? ev;
    QuerySnapshot<Map<String, dynamic>>? floors, features, graphs;
    Timer? timeout;

    void emit() {
      if (ev == null || floors == null || features == null || graphs == null) {
        return;
      }
      timeout?.cancel();
      final data = ev!.data();
      if (data == null || ((data['publishedVersion'] as num?) ?? 0) <= 0) {
        out.addError(const EventNotFound());
        return;
      }
      try {
        final venue = VenueMap(
          floors: [
            for (final d in floors!.docs) Floor.fromJson(d.data(), id: d.id),
          ]..sort((a, b) => a.order.compareTo(b.order)),
          features: [
            for (final d in features!.docs)
              Feature.fromJson(d.data(), id: d.id),
          ],
          graphs: [
            for (final d in graphs!.docs)
              FloorGraph.fromJson(d.data(), floorId: d.id),
          ],
          version: (data['publishedVersion'] as num).toInt(),
        );
        out.add(
          PublishedEvent(
            id: eventId,
            name: data['name'] as String? ?? '',
            map: venue,
          ),
        );
      } on Object catch (e, st) {
        out.addError(e, st);
      }
    }

    void onError(Object e, StackTrace st) {
      timeout?.cancel();
      // Rules deny reads of unpublished or unknown events.
      out.addError(
        e is FirebaseException && e.code == 'permission-denied'
            ? const EventNotFound()
            : e,
        st,
      );
    }

    out = StreamController<PublishedEvent>(
      onListen: () {
        timeout = Timer(
          firstDataTimeout,
          () => out.addError(const MapUnavailable()),
        );
        subs
          ..add(
            event.snapshots().listen((s) {
              ev = s;
              emit();
            }, onError: onError),
          )
          ..add(
            map.collection('floors').snapshots().listen((s) {
              floors = s;
              emit();
            }, onError: onError),
          )
          ..add(
            map.collection('features').snapshots().listen((s) {
              features = s;
              emit();
            }, onError: onError),
          )
          ..add(
            map.collection('graphs').snapshots().listen((s) {
              graphs = s;
              emit();
            }, onError: onError),
          );
      },
      onCancel: () async {
        timeout?.cancel();
        await Future.wait(subs.map((s) => s.cancel()));
      },
    );
    return out.stream;
  }
}
