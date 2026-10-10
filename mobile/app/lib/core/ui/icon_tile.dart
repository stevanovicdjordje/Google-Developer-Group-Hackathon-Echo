import 'package:flutter/material.dart';

import '../theme.dart';

/// 40×40 tinted rounded square with an icon (feature lists, list leading).
/// Primary tint by default; `live: true` uses the live-accent tint.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.live = false, this.size = 40});

  final IconData icon;
  final bool live;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eho = context.eho;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: live ? eho.liveContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: live ? eho.onLiveContainer : scheme.primary,
      ),
    );
  }
}
