import 'package:flutter/material.dart';

const _seed = Color(0xFF1565C0);

ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    // Large tap targets: the app is used one-handed in crowded venues.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
    ),
  );
}

final lightTheme = _build(Brightness.light);
final darkTheme = _build(Brightness.dark);
