import 'package:flutter/material.dart';

/// The design's card: white, radius 18, no shadow, 16 px padding, optional
/// border (e.g. 2 px `context.eho.live` for a live session) and tap.
class EhoCard extends StatelessWidget {
  const EhoCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth = 2,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Defaults to `colorScheme.surface`; use `primaryContainer` etc. for tints.
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!, width: borderWidth),
    );
    return Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
