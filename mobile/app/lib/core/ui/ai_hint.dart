import 'package:flutter/material.dart';

/// Sparkle icon + short text, marking AI-generated content
/// (e.g. "Catch-up", "AI answer", a match reason).
class AiHint extends StatelessWidget {
  const AiHint(this.text, {super.key, this.color, this.style});

  final String text;

  /// Icon and text color. Defaults to `colorScheme.primary`.
  final Color? color;

  /// Defaults to `labelLarge` (14/600).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome, size: 18, color: c),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: (style ?? theme.textTheme.labelLarge)?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}
