import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/maps_localizations.dart';
import 'editor_providers.dart';
import 'maps_api.dart';

/// Shows [child] to a signed-in organizer, the sign-in form otherwise.
class OrganizerGate extends ConsumerWidget {
  const OrganizerGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(organizerUserProvider);
    return switch (user) {
      AsyncData(value: null) || AsyncError() => const _SignInScreen(),
      AsyncData() => child,
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool create = false}) async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      if (create) {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = MapsLocalizations.of(context)
                  .signInFailed(e.message ?? e.code),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                l10n.signInTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                decoration: _signInField(context, l10n.email),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                decoration: _signInField(context, l10n.password),
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(l10n.signIn),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _submit(create: true),
                child: Text(l10n.createAccount),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The organizer's events (`/o`).
class OrganizerHomeScreen extends ConsumerWidget {
  const OrganizerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const OrganizerGate(child: _EventsList());
}

class _EventsList extends ConsumerWidget {
  const _EventsList();

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<OrganizerEvent>(
      context: context,
      builder: (_) => const _NewEventDialog(),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(myEventsProvider);
    context.push('/o/e/${created.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = MapsLocalizations.of(context);
    final events = ref.watch(myEventsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.organizerTitle),
        actions: [
          IconButton(
            tooltip: l10n.reload,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myEventsProvider),
          ),
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.newEvent),
      ),
      body: events.when(
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.noEvents))
            : ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final e in list)
                    ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text(e.name),
                      subtitle: Text(
                        '${e.startDate} – ${e.endDate} · ${e.publishedVersion > 0 ? l10n.publishedVersion(e.publishedVersion) : l10n.notPublished}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/o/e/${e.id}'),
                    ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.mapUnavailable, textAlign: TextAlign.center),
              ),
              FilledButton.icon(
                onPressed: () => ref.invalidate(myEventsProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewEventDialog extends ConsumerStatefulWidget {
  const _NewEventDialog();

  @override
  ConsumerState<_NewEventDialog> createState() => _NewEventDialogState();
}

class _NewEventDialogState extends ConsumerState<_NewEventDialog> {
  final _name = TextEditingController();
  late DateTimeRange _dates = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()),
    end: DateUtils.dateOnly(DateTime.now()),
  );
  String? _error;
  bool _busy = false;

  static final _fmt = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _dates,
    );
    if (r != null) setState(() => _dates = r);
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final e = await ref
          .read(mapsApiProvider)
          .createEvent(
            name: _name.text.trim(),
            startDate: _fmt.format(_dates.start),
            endDate: _fmt.format(_dates.end),
          );
      if (mounted) Navigator.pop(context, e);
    } on MapsApiException catch (e) {
      setState(() {
        _busy = false;
        _error = [e.message, ...e.fieldErrors].join('\n');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newEvent),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 120,
              decoration: InputDecoration(labelText: l10n.eventName),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.eventDates(
                      _fmt.format(_dates.start),
                      _fmt.format(_dates.end),
                    ),
                  ),
                ),
                TextButton(onPressed: _pickDates, child: Text(l10n.pickDates)),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy || _name.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.create),
        ),
      ],
    );
  }
}

/// Sign-in input: 54 high, radius 16 (design tokens).
InputDecoration _signInField(BuildContext context, String label) =>
    InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
