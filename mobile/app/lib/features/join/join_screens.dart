import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/demo_data.dart' as demo;
import '../../data/models.dart';
import '../../data/repositories.dart';

final eventSummaryProvider = FutureProvider.family<EventSummary, String>(
  (ref, id) => ref.watch(eventRepositoryProvider).getEvent(id),
);

/// `/e/{eventId}` for someone who hasn't joined yet (the deep-link landing).
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  bool _joining = false;

  Future<void> _join(EventSummary event) async {
    final profile = ref.read(profileProvider);
    if (!profile.onboarded) {
      final done = await context.push<bool>('/onboarding');
      if (done != true || !mounted) return;
    }
    setState(() => _joining = true);
    await ref.read(eventRepositoryProvider).join(event.id);
    ref.read(joinedEventsProvider.notifier).add(event);
    if (!mounted) return;
    context.go('/e/${event.id}/agenda');
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventSummaryProvider(widget.eventId));
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load event: $e')),
        data: (e) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("You're invited to", style: t.titleMedium),
              const SizedBox(height: 8),
              Text(e.name, style: t.headlineMedium),
              const SizedBox(height: 8),
              Text('${e.dates}\n${e.venue}', style: t.bodyLarge),
              const SizedBox(height: 24),
              const _Perk(Icons.calendar_month, 'Agenda for every stage'),
              const _Perk(Icons.map_outlined, 'Venue map'),
              const _Perk(Icons.graphic_eq, 'Live transcripts and AI answers in every talk'),
              const _Perk(Icons.people_outline, 'Find the people worth meeting'),
              const Spacer(),
              FilledButton(
                onPressed: _joining ? null : () => _join(e),
                child: Text(_joining ? 'Joining…' : 'Join event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(text),
  );
}

/// `/onboarding`: name, interests, goals, consent. Pops `true` when done.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController();
  final _headline = TextEditingController();
  final _lookingFor = TextEditingController();
  final _interests = <String>{};
  bool _visible = true;
  bool _contact = true;
  bool _meetingSpot = true;
  int _step = 0;

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
      _page.animateToPage(
        _step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    ref
        .read(profileProvider.notifier)
        .save(
          Profile(
            name: _name.text.trim(),
            headline: _headline.text.trim(),
            interests: _interests.toList(),
            lookingFor: _lookingFor.text.trim(),
            visibleInFind: _visible,
            allowContact: _contact,
            shareMeetingSpot: _meetingSpot,
            onboarded: true,
          ),
        );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_step + 1} of 3'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / 3),
        ),
      ),
      body: PageView(
        controller: _page,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Who are you?', style: t.headlineSmall),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _headline,
                decoration: const InputDecoration(
                  labelText: 'What you do',
                  hintText: 'e.g. Android dev at Fintio',
                ),
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('What are you into?', style: t.headlineSmall),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in demo.interestOptions)
                    FilterChip(
                      label: Text(i),
                      selected: _interests.contains(i),
                      onSelected: (on) => setState(
                        () => on ? _interests.add(i) : _interests.remove(i),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _lookingFor,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Who do you want to meet?',
                  hintText: 'e.g. people who shipped on-device ML',
                ),
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('You decide what others see', style: t.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'You can change these any time in Profile.',
                style: t.bodyMedium,
              ),
              SwitchListTile(
                title: const Text('Show me in Find'),
                subtitle: const Text(
                  'Others at this event can get you as a recommendation.',
                ),
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
              SwitchListTile(
                title: const Text('Allow contact requests'),
                subtitle: const Text(
                  'Your details are shared only if you accept.',
                ),
                value: _contact,
                onChanged: (v) => setState(() => _contact = v),
              ),
              SwitchListTile(
                title: const Text('Allow meeting spots'),
                subtitle: const Text(
                  'Agree on a place to meet. Never your live location.',
                ),
                value: _meetingSpot,
                onChanged: (v) => setState(() => _meetingSpot = v),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _next,
            child: Text(_step < 2 ? 'Continue' : 'Done'),
          ),
        ),
      ),
    );
  }
}

/// `/events`: every event joined via a link (the event picker).
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(joinedEventsProvider);
    final upcoming = events.where((e) => !e.isPast).toList();
    final past = events.where((e) => e.isPast).toList();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My events')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (upcoming.isNotEmpty) _Header('Now & upcoming', t),
          for (final e in upcoming) _EventTile(e),
          if (past.isNotEmpty) _Header('Past', t),
          for (final e in past) _EventTile(e),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Open an event link to join your first event.'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Join event'),
        onPressed: () => context.go('/'),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, this.t);

  final String text;
  final TextTheme t;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: t.titleSmall),
  );
}

class _EventTile extends ConsumerWidget {
  const _EventTile(this.event);

  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: ListTile(
      title: Text(event.name),
      subtitle: Text('${event.dates} · ${event.venue}'),
      trailing: PopupMenuButton<String>(
        onSelected: (_) =>
            ref.read(joinedEventsProvider.notifier).remove(event.id),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'leave', child: Text('Leave event')),
        ],
      ),
      onTap: () => context.go('/e/${event.id}/agenda'),
    ),
  );
}
