import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

/// `/`: entry point when the app is opened without a link.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomPaint(
                            size: const Size.square(96),
                            painter: _EchoMarkPainter(
                              theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(l10n.appTitle, style: t.displayLarge),
                          const SizedBox(height: 20),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              l10n.startTagline,
                              style: t.bodyLarge?.copyWith(
                                fontSize: 20,
                                height: 1.4,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n.startJoinButton),
                onPressed: () => _joinDialog(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.go('/events'),
                child: Text(l10n.myEvents),
              ),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => context.go('/organizer'),
                child: Text(l10n.startOrganizerButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinDialog(BuildContext context) async {
    final controller = TextEditingController(text: demoEventId);
    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.joinDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.joinDialogLabel),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(l10n.open),
            ),
          ],
        );
      },
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    // Accept a full link (…/e/{id}) or a bare code.
    final id =
        Uri.tryParse(code.trim())?.pathSegments
            .lastWhere((s) => s.isNotEmpty, orElse: () => code.trim()) ??
        code.trim();
    context.go('/e/$id');
  }
}

/// The Eho mark: a dot and three fading arcs (the design's 96x96 "echo" icon).
class _EchoMarkPainter extends CustomPainter {
  const _EchoMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96, size.height / 96);
    canvas.drawCircle(const Offset(30, 48), 9, Paint()..color = color);
    // (start x, start y, radius, chord length, opacity)
    const arcs = [
      (50.0, 30.0, 26.0, 36.0, 1.0),
      (64.0, 20.0, 40.0, 56.0, 0.55),
      (78.0, 10.0, 54.0, 76.0, 0.25),
    ];
    for (final (x, y, r, chord, opacity) in arcs) {
      final path = Path()
        ..moveTo(x, y)
        ..arcToPoint(Offset(x, y + chord), radius: Radius.circular(r));
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_EchoMarkPainter old) => old.color != color;
}
