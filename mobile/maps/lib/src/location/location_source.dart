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
    try {
      yield* Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      ).map((p) => GpsFix(LatLngDeg(p.latitude, p.longitude), p.accuracy));
    } on PermissionDeniedException {
      throw const LocationUnavailable(LocationProblem.denied);
    } on LocationServiceDisabledException {
      throw const LocationUnavailable(LocationProblem.serviceOff);
    }
  }
}

final locationSourceProvider = Provider<LocationSource>(
  (ref) => GeolocatorLocationSource(),
);
