import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/demo_data.dart' as demo;
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.joinLoadError('$e'))),
        data: (e) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.joinInvited, style: t.titleMedium),
              const SizedBox(height: 8),
              Text(e.name, style: t.headlineMedium),
              const SizedBox(height: 8),
              Text('${e.dates}\n${e.venue}', style: t.bodyLarge),
              const SizedBox(height: 24),
              _Perk(Icons.calendar_month, l10n.joinPerkAgenda),
              _Perk(Icons.map_outlined, l10n.joinPerkMap),
              _Perk(Icons.graphic_eq, l10n.joinPerkEcho),
              _Perk(Icons.people_outline, l10n.joinPerkFind),
              const Spacer(),
              FilledButton(
                onPressed: _joining ? null : () => _join(e),
                child: Text(_joining ? l10n.joinJoining : l10n.joinEvent),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingStep(_step + 1, 3)),
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
              Text(l10n.onboardingWhoTitle, style: t.headlineSmall),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.onboardingName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _headline,
                decoration: InputDecoration(
                  labelText: l10n.onboardingHeadline,
                  hintText: l10n.onboardingHeadlineHint,
                ),
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(l10n.onboardingInterestsTitle, style: t.headlineSmall),
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
                decoration: InputDecoration(
                  labelText: l10n.onboardingLookingForLabel,
                  hintText: l10n.onboardingLookingForHint,
                ),
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(l10n.onboardingPrivacyTitle, style: t.headlineSmall),
              const SizedBox(height: 8),
              Text(l10n.onboardingPrivacyBody, style: t.bodyMedium),
              SwitchListTile(
                title: Text(l10n.showMeInFind),
                subtitle: Text(l10n.showMeInFindSubtitle),
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
              SwitchListTile(
                title: Text(l10n.allowContactRequests),
                subtitle: Text(l10n.allowContactRequestsSubtitle),
                value: _contact,
                onChanged: (v) => setState(() => _contact = v),
              ),
              SwitchListTile(
                title: Text(l10n.allowMeetingSpots),
                subtitle: Text(l10n.allowMeetingSpotsSubtitle),
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
            child: Text(_step < 2 ? l10n.continueButton : l10n.done),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myEvents)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (upcoming.isNotEmpty) _Header(l10n.myEventsUpcoming, t),
          for (final e in upcoming) _EventTile(e),
          if (past.isNotEmpty) _Header(l10n.myEventsPast, t),
          for (final e in past) _EventTile(e),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.myEventsEmpty),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.joinEvent),
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
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'leave',
            child: Text(AppLocalizations.of(context).leaveEvent),
          ),
        ],
      ),
      onTap: () => context.go('/e/${event.id}/agenda'),
    ),
  );
}
