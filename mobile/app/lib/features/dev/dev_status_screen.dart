import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';

final backendHealthProvider = FutureProvider<void>((ref) {
  return ref.watch(apiClientProvider).healthz();
});

/// Development screen: shows that the app reaches the backend and Firebase Auth.
class DevStatusScreen extends ConsumerWidget {
  const DevStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final health = ref.watch(backendHealthProvider);
    final signIn = ref.watch(ensureSignedInProvider);

    String describe<T>(AsyncValue<T> v, String Function(T) ok) => v.when(
      data: ok,
      loading: () => l10n.statusChecking,
      error: (e, _) => l10n.statusError(e.toString()),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devStatusTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusTile(
            label: l10n.backendLabel,
            value: describe(health, (_) => l10n.statusOk),
            ok: health.hasValue,
            failed: health.hasError,
          ),
          _StatusTile(
            label: l10n.authLabel,
            value: describe(signIn, (uid) => l10n.signedInAnonymously(uid)),
            ok: signIn.hasValue,
            failed: signIn.hasError,
          ),
          const SizedBox(height: 24),
          const _OpenEvent(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(backendHealthProvider);
              ref.invalidate(ensureSignedInProvider);
            },
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.value,
    required this.ok,
    required this.failed,
  });

  final String label;
  final String value;
  final bool ok;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          ok
              ? Icons.check_circle
              : (failed ? Icons.error : Icons.hourglass_top),
          color: ok ? Colors.green : (failed ? scheme.error : null),
        ),
        title: Text(label),
        subtitle: Text(value),
      ),
    );
  }
}

/// Opens an event's map by ID (for local testing; attendees use links/QR).
class _OpenEvent extends StatefulWidget {
  const _OpenEvent();

  @override
  State<_OpenEvent> createState() => _OpenEventState();
}

class _OpenEventState extends State<_OpenEvent> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    final id = _ctrl.text.trim();
    if (id.isNotEmpty) context.go('/e/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: l10n.openEventLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _open(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _open, child: Text(l10n.openEvent)),
      ],
    );
  }
}
