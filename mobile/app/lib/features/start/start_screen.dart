import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories.dart';

/// `/`: entry point when the app is opened without a link.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('Eho', style: t.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Your AI companion for events: agenda, venue, talks and people.',
                style: t.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Join with a link or code'),
                onPressed: () => _joinDialog(context),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_note),
                label: const Text('My events'),
                onPressed: () => context.go('/events'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.storefront),
                label: const Text("I'm an organizer"),
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
      builder: (context) => AlertDialog(
        title: const Text('Join an event'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Event link or code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
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
