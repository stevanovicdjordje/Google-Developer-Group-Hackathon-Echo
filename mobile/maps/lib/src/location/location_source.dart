import 'dart:async';
import 'dart:math' as math;

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

/// A source that can tell whether [LocationSource.watch] would start without
/// asking the user anything (no permission prompt, location service on).
/// Used by `MapViewerScreen(locateOnOpen: true)`; other sources never start
/// on their own.
abstract interface class QuietLocationSource implements LocationSource {
  Future<bool> allowedWithoutPrompt();
}

class GeolocatorLocationSource implements QuietLocationSource {
  /// Only checks; never calls `requestPermission()`.
  @override
  Future<bool> allowedWithoutPrompt() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.whileInUse ||
          p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

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

/// Demo/dev only: a pretend position instead of the device GPS, for showing
/// the GPS dot on a venue that isn't where the phone is (mobile#14).
/// `--dart-define=DEMO_LOCATION=<lat>,<lng>` stands still there;
/// `<lat>,<lng>;<lat>,<lng>;…` walks along the points at [walkSpeed] and
/// stays at the last one. Needs no location permission.
class DemoLocationSource implements QuietLocationSource {
  DemoLocationSource(
    this.path, {
    this.accuracyMeters = 5,
    this.walkSpeed = 1.2,
    this.interval = const Duration(seconds: 1),
  }) : assert(path.isNotEmpty);

  final List<LatLngDeg> path;
  final double accuracyMeters;

  /// Meters per second.
  final double walkSpeed;
  final Duration interval;

  /// Parses a `DEMO_LOCATION` value; null if empty or malformed.
  static DemoLocationSource? parse(String value) {
    if (value.trim().isEmpty) return null;
    final path = <LatLngDeg>[];
    for (final part in value.split(';')) {
      final nums = part.split(',').map((s) => double.tryParse(s.trim()));
      if (nums.length != 2 || nums.contains(null)) return null;
      final [lat, lng] = nums.toList();
      if (lat!.abs() > 90 || lng!.abs() > 180) return null;
      path.add(LatLngDeg(lat, lng));
    }
    return DemoLocationSource(path);
  }

  /// A pretend position never needs a permission.
  @override
  Future<bool> allowedWithoutPrompt() async => true;

  /// Where the walk is after [seconds].
  LatLngDeg positionAt(double seconds) {
    var left = seconds * walkSpeed;
    for (var i = 0; i + 1 < path.length; i++) {
      final a = path[i], b = path[i + 1];
      final d = _meters(a, b);
      if (left <= d) {
        final t = d == 0 ? 1.0 : left / d;
        return LatLngDeg(
          a.lat + (b.lat - a.lat) * t,
          a.lng + (b.lng - a.lng) * t,
        );
      }
      left -= d;
    }
    return path.last;
  }

  @override
  Stream<GpsFix> watch() async* {
    final started = DateTime.now();
    yield GpsFix(path.first, accuracyMeters);
    if (path.length == 1) return; // standing still: one fix is enough
    await for (final _ in Stream<void>.periodic(interval)) {
      final s = DateTime.now().difference(started).inMilliseconds / 1000;
      yield GpsFix(positionAt(s), accuracyMeters);
    }
  }

  /// Equirectangular distance; fine over a venue.
  static double _meters(LatLngDeg a, LatLngDeg b) {
    const r = 6371008.8;
    final x =
        (b.lng - a.lng) *
        math.pi /
        180 *
        math.cos((a.lat + b.lat) * math.pi / 360);
    final y = (b.lat - a.lat) * math.pi / 180;
    return math.sqrt(x * x + y * y) * r;
  }
}

const _demoLocation = String.fromEnvironment('DEMO_LOCATION');

/// The device GPS, or [DemoLocationSource] when `DEMO_LOCATION` is set. The
/// app may override it (e.g. a dev toggle).
final locationSourceProvider = Provider<LocationSource>(
  (ref) =>
      DemoLocationSource.parse(_demoLocation) ?? GeolocatorLocationSource(),
);
