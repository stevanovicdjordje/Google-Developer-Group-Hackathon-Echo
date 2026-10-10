import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

/// `/`: entry point when the app is opened without a link.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(l10n.appTitle, style: t.displayMedium),
              const SizedBox(height: 8),
              Text(l10n.startTagline, style: t.titleMedium),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n.startJoinButton),
                onPressed: () => _joinDialog(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_note),
                label: Text(l10n.myEvents),
                onPressed: () => context.go('/events'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.storefront),
                label: Text(l10n.startOrganizerButton),
                onPressed: () => context.go('/organizer'),
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
    final id = Uri.tryParse(code.trim())?.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => code.trim(),
        ) ??
        code.trim();
    context.go('/e/$id');
  }
}
