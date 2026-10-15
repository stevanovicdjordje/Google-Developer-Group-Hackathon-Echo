import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar over a light screen: transparent, dark icons (Android reads
/// `statusBarIconBrightness`, iOS reads `statusBarBrightness`, which names the
/// brightness of the *content behind* the bar, so it is inverted).
const ehoStatusBarOnLight = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
);

/// Status bar over a dark (ink) header: transparent, light icons.
const ehoStatusBarOnDark = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
);

/// Design tokens from `mobile/docs/design/README.md`. Screens never use these
/// directly: read them via `Theme.of(context).colorScheme` / `textTheme` or
/// `context.eho` (see `EhoColors`). The app is light-only (the demo is light).
abstract final class _Tokens {
  static const background = Color(0xFFF3F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0D1321);
  static const inkSecondary = Color(0xFF4A5468);
  static const bodyOnTint = Color(0xFF1F2A44);
  static const outline = Color(0xFFC9D0DC);
  static const divider = Color(0xFFDDE2EB);
  static const primary = Color(0xFF2F4BFF);
  static const primaryPressed = Color(0xFF1A33D6);
  static const primaryContainer = Color(0xFFE6EAFF);
  static const live = Color(0xFFE85D1F);
  static const liveContainer = Color(0xFFFFEDE3);
  static const onLiveContainer = Color(0xFFC2410C);
  static const onInkMuted = Color(0xFFD5DBE6);
  static const onInkPrimary = Color(0xFFB9C3FF);
  static const onInkLive = Color(0xFFFFB48C);
}

/// Font families bundled in `assets/fonts/` (OFL).
const displayFont = 'Bricolage Grotesque';
const bodyFont = 'Instrument Sans';

/// Tokens that don't map cleanly onto [ColorScheme]. Read with `context.eho`.
@immutable
class EhoColors extends ThemeExtension<EhoColors> {
  const EhoColors({
    required this.live,
    required this.onLive,
    required this.liveContainer,
    required this.onLiveContainer,
    required this.ink,
    required this.onInk,
    required this.onInkMuted,
    required this.onInkPrimary,
    required this.onInkLive,
    required this.inkOverlay,
    required this.bodyOnTint,
    required this.primaryPressed,
    required this.background,
  });

  /// Live accent: LIVE dot, live session border, badges, meeting-spot border.
  final Color live;
  final Color onLive;

  /// Highlighted transcript line, meeting-spot icon tile.
  final Color liveContainer;

  /// LIVE label text, icons on [liveContainer].
  final Color onLiveContainer;

  /// Dark hero blocks (Join header, live event card), selected filter chip.
  final Color ink;
  final Color onInk;

  /// Secondary text on [ink] blocks.
  final Color onInkMuted;

  /// Accent text on [ink] blocks (e.g. "You're invited to").
  final Color onInkPrimary;

  /// Live-accent text on [ink] blocks.
  final Color onInkLive;

  /// Translucent fill for round buttons on [ink] blocks.
  final Color inkOverlay;

  /// Body text on tinted cards (primary/live containers).
  final Color bodyOnTint;

  /// Pressed / emphasized primary (also links on tint).
  final Color primaryPressed;

  /// Screen ground (same as `scaffoldBackgroundColor`).
  final Color background;

  @override
  EhoColors copyWith({
    Color? live,
    Color? onLive,
    Color? liveContainer,
    Color? onLiveContainer,
    Color? ink,
    Color? onInk,
    Color? onInkMuted,
    Color? onInkPrimary,
    Color? onInkLive,
    Color? inkOverlay,
    Color? bodyOnTint,
    Color? primaryPressed,
    Color? background,
  }) {
    return EhoColors(
      live: live ?? this.live,
      onLive: onLive ?? this.onLive,
      liveContainer: liveContainer ?? this.liveContainer,
      onLiveContainer: onLiveContainer ?? this.onLiveContainer,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      onInkMuted: onInkMuted ?? this.onInkMuted,
      onInkPrimary: onInkPrimary ?? this.onInkPrimary,
      onInkLive: onInkLive ?? this.onInkLive,
      inkOverlay: inkOverlay ?? this.inkOverlay,
      bodyOnTint: bodyOnTint ?? this.bodyOnTint,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      background: background ?? this.background,
    );
  }

  @override
  EhoColors lerp(EhoColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return EhoColors(
      live: l(live, other.live),
      onLive: l(onLive, other.onLive),
      liveContainer: l(liveContainer, other.liveContainer),
      onLiveContainer: l(onLiveContainer, other.onLiveContainer),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      onInkMuted: l(onInkMuted, other.onInkMuted),
      onInkPrimary: l(onInkPrimary, other.onInkPrimary),
      onInkLive: l(onInkLive, other.onInkLive),
      inkOverlay: l(inkOverlay, other.inkOverlay),
      bodyOnTint: l(bodyOnTint, other.bodyOnTint),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      background: l(background, other.background),
    );
  }
}

const _ehoLight = EhoColors(
  live: _Tokens.live,
  onLive: Colors.white,
  liveContainer: _Tokens.liveContainer,
  onLiveContainer: _Tokens.onLiveContainer,
  ink: _Tokens.ink,
  onInk: Colors.white,
  onInkMuted: _Tokens.onInkMuted,
  onInkPrimary: _Tokens.onInkPrimary,
  onInkLive: _Tokens.onInkLive,
  inkOverlay: Color(0x1FFFFFFF),
  bodyOnTint: _Tokens.bodyOnTint,
  primaryPressed: _Tokens.primaryPressed,
  background: _Tokens.background,
);

extension EhoThemeContext on BuildContext {
  /// The Eho-specific color tokens (`context.eho.live`, `context.eho.ink`, …).
  EhoColors get eho => Theme.of(this).extension<EhoColors>() ?? _ehoLight;
}

const _scheme = ColorScheme(
  brightness: Brightness.light,
  primary: _Tokens.primary,
  onPrimary: Colors.white,
  primaryContainer: _Tokens.primaryContainer,
  onPrimaryContainer: _Tokens.primaryPressed,
  secondary: _Tokens.live,
  onSecondary: Colors.white,
  secondaryContainer: _Tokens.liveContainer,
  onSecondaryContainer: _Tokens.onLiveContainer,
  tertiary: _Tokens.live,
  onTertiary: Colors.white,
  tertiaryContainer: _Tokens.liveContainer,
  onTertiaryContainer: _Tokens.onLiveContainer,
  error: Color(0xFFC62828),
  onError: Colors.white,
  errorContainer: Color(0xFFFDE7E7),
  onErrorContainer: Color(0xFF8E1B1B),
  surface: _Tokens.surface,
  onSurface: _Tokens.ink,
  onSurfaceVariant: _Tokens.inkSecondary,
  surfaceDim: _Tokens.divider,
  surfaceBright: _Tokens.surface,
  surfaceContainerLowest: _Tokens.surface,
  surfaceContainerLow: Color(0xFFF8F9FC),
  surfaceContainer: _Tokens.background,
  surfaceContainerHigh: Color(0xFFEDF0F5),
  surfaceContainerHighest: Color(0xFFE6EAF0),
  outline: _Tokens.outline,
  outlineVariant: _Tokens.divider,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: _Tokens.ink,
  onInverseSurface: Colors.white,
  inversePrimary: _Tokens.onInkPrimary,
  surfaceTint: Colors.transparent,
);

TextStyle _display(double size, double height, double spacing) => TextStyle(
  fontFamily: displayFont,
  fontWeight: FontWeight.w700,
  fontSize: size,
  height: height,
  letterSpacing: spacing,
);

TextStyle _body(
  double size,
  FontWeight weight, {
  double height = 1.4,
  double spacing = 0,
}) => TextStyle(
  fontFamily: bodyFont,
  fontWeight: weight,
  fontSize: size,
  height: height,
  letterSpacing: spacing,
);

final _textTheme = TextTheme(
  // Bricolage Grotesque 700, tight tracking.
  displayLarge: _display(72, 0.95, -2), // Start wordmark
  displayMedium: _display(40, 1.02, -1), // Join hero title
  displaySmall: _display(34, 1.05, -0.5),
  headlineLarge: _display(32, 1.1, -0.5), // screen titles ("Agenda")
  headlineMedium: _display(26, 1.1, -0.5), // event card title
  headlineSmall: _display(24, 1.15, -0.3),
  titleLarge: _display(20, 1.2, -0.2), // app bar, sheet titles
  // Instrument Sans.
  titleMedium: _body(17, FontWeight.w600, height: 1.3), // card / list titles
  titleSmall: _body(15, FontWeight.w600, height: 1.3),
  bodyLarge: _body(17, FontWeight.w400, height: 1.45),
  bodyMedium: _body(15, FontWeight.w400, height: 1.45),
  bodySmall: _body(14, FontWeight.w400),
  labelLarge: _body(14, FontWeight.w600), // chips, small buttons
  labelMedium: _body(13, FontWeight.w500),
  labelSmall: _body(12, FontWeight.w600, spacing: 0.6), // overline / LIVE label
);

const _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
);
const _buttonSize = Size(64, 56);
final _buttonText = _body(17, FontWeight.w600);

ThemeData _build() {
  const s = _scheme;
  final text = _textTheme.apply(
    bodyColor: s.onSurface,
    displayColor: s.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: s,
    fontFamily: bodyFont,
    textTheme: text,
    scaffoldBackgroundColor: _Tokens.background,
    canvasColor: _Tokens.background,
    dividerColor: s.outlineVariant,
    extensions: const [_ehoLight],
    // Large tap targets: the app is used one-handed in crowded venues.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: _Tokens.background,
      foregroundColor: s.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: ehoStatusBarOnLight,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: _buttonSize,
        shape: _buttonShape,
        textStyle: _buttonText,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: _buttonSize,
        shape: _buttonShape,
        textStyle: _buttonText,
        backgroundColor: s.primary,
        foregroundColor: s.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: _buttonSize,
        shape: _buttonShape,
        textStyle: _buttonText,
        backgroundColor: s.surface,
        foregroundColor: s.onSurface,
        side: BorderSide(color: s.outline, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: _buttonShape,
        foregroundColor: s.primary,
        textStyle: _body(16, FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primary,
      foregroundColor: s.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: _buttonShape,
      extendedTextStyle: _buttonText,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: s.surface,
      selectedColor: _Tokens.ink,
      secondarySelectedColor: _Tokens.ink,
      checkmarkColor: Colors.white,
      // RawChip resolves only the label *color* per state.
      labelStyle: _body(14, FontWeight.w600, height: 1.2).copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : s.onSurface,
        ),
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const BorderSide(color: _Tokens.ink)
            : BorderSide(color: s.outline),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: s.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: _body(16, FontWeight.w400).copyWith(color: s.onSurfaceVariant),
      labelStyle: _body(16, FontWeight.w400).copyWith(
        color: s.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: s.outline, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: s.outline, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: s.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: s.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: s.error, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: s.outlineVariant,
      elevation: 0,
      height: 72,
      indicatorColor: s.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateTextStyle.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? _body(12, FontWeight.w600).copyWith(color: s.primary)
            : _body(12, FontWeight.w500).copyWith(color: s.onSurfaceVariant),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? s.primary
              : s.onSurfaceVariant,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: s.surfaceContainer,
        foregroundColor: s.onSurfaceVariant,
        selectedBackgroundColor: s.surface,
        selectedForegroundColor: s.primary,
        side: BorderSide(color: s.outlineVariant),
        textStyle: _body(14, FontWeight.w600),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: s.onSurfaceVariant,
      titleTextStyle: _body(
        17,
        FontWeight.w500,
        height: 1.3,
      ).copyWith(color: s.onSurface),
      subtitleTextStyle: _body(14, FontWeight.w400).copyWith(
        color: s.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: s.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _Tokens.ink,
      contentTextStyle: _body(15, FontWeight.w500).copyWith(
        color: Colors.white,
      ),
      actionTextColor: _Tokens.onInkPrimary,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: s.surface,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: s.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      titleTextStyle: text.titleLarge,
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : s.outline,
      ),
    ),
  );
}

final lightTheme = _build();
