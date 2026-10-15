import 'package:flutter/material.dart';

/// Uppercase overline above a group, e.g. "WITH EHO YOU GET".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.padding});

  final String label;

  /// Defaults to 8 px below the label.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
