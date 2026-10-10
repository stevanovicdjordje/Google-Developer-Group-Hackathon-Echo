import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../model/map_models.dart';

/// One GPS reading. Used only on the device (and as a route start); never
/// stored or logged (`docs/DATA_PRIVACY.md` → Location).
class GpsFix {
  const GpsFix(this.position, this.accuracyMeters);

  final LatLngDeg position;

  /// Radius of the 68 % confidence circle.
  final double accuracyMeters;
}

/// Why there is no position.
enum LocationProblem { serviceOff, denied, failed }

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.problem);

  final LocationProblem problem;

  @override
  String toString() => 'LocationUnavailable($problem)';
}

/// Live device position. Overridden in tests.
abstract class LocationSource {
  /// Asks for permission if needed, then streams fixes. Errors are
  /// [LocationUnavailable].
  Stream<GpsFix> watch();
}

class GeolocatorLocationSource implements LocationSource {
  @override
  Stream<GpsFix> watch() async* {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailable(LocationProblem.serviceOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationUnavailable(LocationProblem.denied);
    }
    // Errors inside the stream are forwarded (not thrown here), so they are
    // translated on the stream itself. A lost signal is `failed` and the
    // stream goes on.
    yield* Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 1,
          ),
        )
        .map((p) => GpsFix(LatLngDeg(p.latitude, p.longitude), p.accuracy))
        .transform(
          StreamTransformer<GpsFix, GpsFix>.fromHandlers(
            handleError: (e, st, sink) => sink.addError(
              LocationUnavailable(switch (e) {
                PermissionDeniedException() => LocationProblem.denied,
                LocationServiceDisabledException() =>
                  LocationProblem.serviceOff,
                _ => LocationProblem.failed,
              }),
              st,
            ),
          ),
        );
  }
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => GeolocatorLocationSource(),
);
