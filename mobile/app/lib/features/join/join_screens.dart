import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/ui/ui.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

final eventSummaryProvider = FutureProvider.family<EventSummary, String>(
  (ref, id) => ref.watch(eventRepositoryProvider).getEvent(id),
);

/// 1-based day of the event the Agenda and My events labels show ("Day N").
/// `EventSummary` has no day list (`dates` is free text) and sessions carry
/// only a time of day, so the demo's agenda is a single day: always 1.
const shownEventDay = 1;

/// The talk that is on right now at an event, if any (for the My events card).
final _liveSessionProvider = FutureProvider.family<Session?, String>((
  ref,
  eventId,
) async {
  final sessions = await ref.watch(eventRepositoryProvider).agenda(eventId);
  return sessions.where((s) => s.isLive).firstOrNull;
});

/// `/e/{eventId}` for someone who hasn't joined yet (the deep-link landing).
/// [markerId] is the optional "you are here" QR marker (`?at=`); after joining
/// the user lands on the map with it instead of the agenda.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, required this.eventId, this.markerId});

  final String eventId;
  final String? markerId;

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
    final at = widget.markerId;
    context.go(
      at == null
          ? '/e/${event.id}/agenda'
          : '/e/${event.id}/map?at=${Uri.encodeComponent(at)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(eventSummaryProvider(widget.eventId));
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: event.hasValue ? null : AppBar(),
      body: event.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.joinLoadError('$e'))),
        data: (e) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: eho.ink,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: eho.inkOverlay,
                                  foregroundColor: eho.onInk,
                                ),
                                tooltip: MaterialLocalizations.of(context)
                                    .backButtonTooltip,
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () => context.canPop()
                                    ? context.pop()
                                    : context.go('/'),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                l10n.joinInvited,
                                style: t.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: eho.onInkPrimary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                e.name,
                                style: t.displayMedium?.copyWith(
                                  color: eho.onInk,
                                  height: 1.02,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                e.dates,
                                style: t.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  color: eho.onInkMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                e.venue,
                                style: t.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  color: eho.onInkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionLabel(
                            l10n.joinWithEho,
                            padding: const EdgeInsets.only(bottom: 4),
                          ),
                          _Perk(Icons.calendar_today, l10n.joinPerkAgenda),
                          _Perk(Icons.map_outlined, l10n.joinPerkMap),
                          _Perk(
                            Icons.graphic_eq,
                            l10n.joinPerkEcho,
                            live: true,
                          ),
                          _Perk(
                            Icons.people_outline,
                            l10n.joinPerkFind,
                            last: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FilledButton(
                  onPressed: _joining ? null : () => _join(e),
                  child: Text(_joining ? l10n.joinJoining : l10n.joinEvent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.text, {this.live = false, this.last = false});

  final IconData icon;
  final String text;
  final bool live;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: last
          ? null
          : Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
    ),
    child: Row(
      children: [
        IconTile(icon, live: live),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
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
    // Close the keyboard on every step change so it never covers the consents.
    FocusManager.instance.primaryFocus?.unfocus();
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

  void _back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    final scheme = theme.colorScheme;
    const pad = EdgeInsets.fromLTRB(24, 24, 24, 0);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surface,
                      foregroundColor: scheme.onSurface,
                    ),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _back,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: i <= _step
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.onboardingStep(_step + 1, 3),
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ListView(
                    padding: pad,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(l10n.onboardingWhoTitle, style: _title(t)),
                      const SizedBox(height: 10),
                      Text(
                        l10n.onboardingWhoSubtitle,
                        style: _subtitle(t, scheme),
                      ),
                      const SizedBox(height: 24),
                      _Field(
                        label: l10n.onboardingName,
                        child: TextField(controller: _name),
                      ),
                      const SizedBox(height: 24),
                      _Field(
                        label: l10n.onboardingHeadline,
                        child: TextField(
                          controller: _headline,
                          decoration: InputDecoration(
                            hintText: l10n.onboardingHeadlineHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: pad,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(l10n.onboardingInterestsTitle, style: _title(t)),
                      const SizedBox(height: 10),
                      Text(
                        l10n.onboardingInterestsSubtitle,
                        style: _subtitle(t, scheme),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final i in ref.watch(interestOptionsProvider))
                            _InterestChip(
                              label: i,
                              selected: _interests.contains(i),
                              onSelected: (on) => setState(
                                () => on
                                    ? _interests.add(i)
                                    : _interests.remove(i),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _Field(
                        label: l10n.onboardingLookingForLabel,
                        child: TextField(
                          controller: _lookingFor,
                          minLines: 3,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: l10n.onboardingLookingForHint,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l10n.onboardingLookingForNote,
                              style: t.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ListView(
                    padding: pad,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(l10n.onboardingPrivacyTitle, style: _title(t)),
                      const SizedBox(height: 10),
                      Text(
                        l10n.onboardingPrivacyBody,
                        style: _subtitle(t, scheme),
                      ),
                      const SizedBox(height: 24),
                      EhoCard(
                        radius: 20,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _ConsentRow(
                              title: l10n.showMeInFind,
                              subtitle: l10n.showMeInFindSubtitle,
                              value: _visible,
                              onChanged: (v) => setState(() => _visible = v),
                            ),
                            const Divider(),
                            _ConsentRow(
                              title: l10n.allowContactRequests,
                              subtitle: l10n.allowContactRequestsSubtitle,
                              value: _contact,
                              onChanged: (v) => setState(() => _contact = v),
                            ),
                            const Divider(),
                            _ConsentRow(
                              title: l10n.allowMeetingSpots,
                              subtitle: l10n.allowMeetingSpotsSubtitle,
                              value: _meetingSpot,
                              onChanged: (v) =>
                                  setState(() => _meetingSpot = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.onboardingPrivacyNote,
                        style: t.bodySmall?.copyWith(
                          height: 1.45,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_step < 2 ? l10n.continueButton : l10n.done),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step headline: Bricolage 34 (the design's big screen title).
  TextStyle? _title(TextTheme t) => t.displaySmall?.copyWith(height: 1.05);

  /// Step subtitle under the headline.
  TextStyle? _subtitle(TextTheme t, ColorScheme scheme) =>
      t.bodyLarge?.copyWith(fontSize: 16, color: scheme.onSurfaceVariant);
}

/// Label above a field (design: 14/600, 8 px gap).
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      child,
    ],
  );
}

/// Interest chip: selected = filled primary, white label; else white + outline.
class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: scheme.primary,
      labelStyle: style?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? scheme.onPrimary : scheme.onSurface,
      ),
      side: selected ? BorderSide.none : null,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      shape: const StadiumBorder(),
    );
  }
}

/// One consent row: title + subtitle and the design's 52x32 toggle.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 52,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: value ? scheme.primary : scheme.outline,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
              child: Text(l10n.myEvents, style: t.displaySmall),
            ),
            if (upcoming.isNotEmpty)
              SectionLabel(
                l10n.myEventsNow,
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
              ),
            for (final e in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _LiveEventCard(e),
              ),
            if (past.isNotEmpty)
              SectionLabel(
                l10n.myEventsPast,
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
              ),
            for (final e in past)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PastEventCard(e),
              ),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(l10n.myEventsEmpty),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.joinEvent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: () => context.go('/'),
      ),
    );
  }
}

/// Overflow menu with "Leave event" (on the past event cards).
class _LeaveMenu extends ConsumerWidget {
  const _LeaveMenu(this.event);

  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
    onSelected: (_) => ref.read(joinedEventsProvider.notifier).remove(event.id),
    itemBuilder: (context) => [
      PopupMenuItem(
        value: 'leave',
        child: Text(AppLocalizations.of(context).leaveEvent),
      ),
    ],
  );
}

/// Dark ink card for an event that is on now / upcoming.
class _LiveEventCard extends ConsumerWidget {
  const _LiveEventCard(this.event);

  final EventSummary event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final live = ref.watch(_liveSessionProvider(event.id)).value;
    return EhoCard(
      color: eho.ink,
      radius: 22,
      padding: const EdgeInsets.all(22),
      onTap: () => context.go('/e/${event.id}/agenda'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (live != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: LiveBadge(
                l10n.myEventsLiveDay(shownEventDay),
                onDark: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            event.name,
            style: t.headlineMedium?.copyWith(color: eho.onInk, height: 1.1),
          ),
          const SizedBox(height: 14),
          Text(
            '${event.dates} · ${event.venue}',
            style: t.bodyMedium?.copyWith(color: eho.onInkMuted),
          ),
          const SizedBox(height: 14),
          Divider(color: eho.inkOverlay),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  live == null
                      ? l10n.tabAgenda
                      : l10n.myEventsNext(live.title, live.start, live.stage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(color: eho.onInk),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: eho.onInk),
            ],
          ),
        ],
      ),
    );
  }
}

/// White card for a past event: date tile, name, venue, overflow menu.
class _PastEventCard extends StatelessWidget {
  const _PastEventCard(this.event);

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = theme.textTheme;
    // "Sep 18, 2026" gives SEP / 18; other formats fall back to an icon.
    final m = RegExp(r'^([A-Za-z]{3})\w*\s+(\d{1,2})').firstMatch(event.dates);
    final tileStyle = t.labelLarge?.copyWith(color: scheme.primary, height: 1);
    return EhoCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      onTap: () => context.go('/e/${event.id}/agenda'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: m == null
                ? Icon(Icons.event, color: scheme.primary)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        m.group(1)!.toUpperCase(),
                        style: tileStyle?.copyWith(fontSize: 11),
                      ),
                      Text(
                        m.group(2)!,
                        style: tileStyle?.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name, style: t.titleMedium),
                const SizedBox(height: 4),
                Text(
                  event.venue,
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _LeaveMenu(event),
        ],
      ),
    );
  }
}
