import 'package:flutter/material.dart';

import '../theme.dart';

/// Live dot + uppercase label, e.g. "LIVE NOW · ECHO ON" or "LIVE · GLAVNA SALA".
/// Pass the label as written in ARB; it is upper-cased here.
class LiveBadge extends StatelessWidget {
  const LiveBadge(this.label, {super.key, this.onDark = false});

  final String label;

  /// Use on ink (dark) blocks: label switches to `onInkLive`.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final eho = context.eho;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: onDark ? eho.onInkLive : eho.onLiveContainer,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: eho.live, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
