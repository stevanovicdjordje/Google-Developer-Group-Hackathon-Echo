import 'dart:async';

import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/ui/ui.dart';
import '../../data/app_state.dart';
import '../../data/demo_data.dart' as demo;
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

/// How long the profile must stay unchanged before recommendations reload.
/// Overridden in tests.
final findReloadDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// Recommendations for the event. Loads once; later profile edits reload it
/// only when they change what the ranking uses (interests, "looking for",
/// visibility) and only after [findReloadDelayProvider] without a further
/// edit, so flicking consent switches doesn't hit the service's rate limit.
/// Opening this (the Find tab) also makes the repository join the event's
/// Find presence, so the first call per event is the join.
final recommendationsProvider =
    FutureProvider.family<List<PersonMatch>, String>((ref, eventId) {
      Timer? timer;
      ref.onDispose(() => timer?.cancel());
      ref.listen(profileProvider, (prev, next) {
        if (prev == null || !_rankingChanged(prev, next)) return;
        timer?.cancel();
        timer = Timer(ref.read(findReloadDelayProvider), ref.invalidateSelf);
      });
      final me = ref.read(profileProvider);
      return ref.watch(findRepositoryProvider).recommendations(eventId, me);
    });

/// Whether a profile edit can change the recommendations.
bool _rankingChanged(Profile a, Profile b) =>
    a.onboarded != b.onboarded ||
    a.visibleInFind != b.visibleInFind ||
    a.lookingFor != b.lookingFor ||
    !listEquals(a.interests, b.interests);

/// One person at an event (`(eventId, personId)`); null when not visible.
final personDetailProvider = FutureProvider.autoDispose
    .family<PersonDetail?, (String, String)>(
      (ref, key) => ref.watch(findRepositoryProvider).person(key.$1, key.$2),
    );

/// Friendly text for a failed Find call.
String _findErrorText(AppLocalizations l10n, Object e) => switch (e) {
  FindException(kind: FindErrorKind.offline) => l10n.findErrorOffline,
  FindException(kind: FindErrorKind.rateLimited) => l10n.findErrorRateLimited,
  FindException(kind: FindErrorKind.aiBusy) => l10n.findErrorAiBusy,
  FindException(kind: FindErrorKind.notFound) => l10n.findErrorNotFound,
  FindException(kind: FindErrorKind.notAllowed) => l10n.findErrorNotAllowed,
  FindException(kind: FindErrorKind.profileRequired) =>
    l10n.findErrorProfileRequired,
  _ => l10n.findErrorFailed,
};

/// Error text with "Try again".
class _FindError extends StatelessWidget {
  const _FindError(this.error, {required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(_findErrorText(l10n, error), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

/// Find tab: AI recommendations, or describe who you want to meet.
class FindScreen extends ConsumerStatefulWidget {
  const FindScreen({super.key, required this.eventId, this.initialPrompt});

  final String eventId;

  /// Starts with this search already run (dev screenshot routes only).
  final String? initialPrompt;

  @override
  ConsumerState<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends ConsumerState<FindScreen> {
  final _prompt = TextEditingController();
  Future<List<PersonMatch>>? _search;

  @override
  void initState() {
    super.initState();
    final p = widget.initialPrompt;
    if (p != null) {
      _prompt.text = p;
      _search = ref.read(findRepositoryProvider).search(widget.eventId, p);
    }
  }

  void _run() {
    final p = _prompt.text.trim();
    if (p.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _search = ref.read(findRepositoryProvider).search(widget.eventId, p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          children: [
            Text(l10n.findTitle, style: t.headlineLarge),
            const SizedBox(height: 14),
            _SearchField(
              controller: _prompt,
              hint: l10n.findSearchHint,
              onSubmit: _run,
              onClear: _search == null
                  ? null
                  : () => setState(() {
                      _search = null;
                      _prompt.clear();
                    }),
            ),
            const SizedBox(height: 20),
            if (_search != null) ...[
              FutureBuilder<List<PersonMatch>>(
                future: _search,
                builder: (context, snap) => snap.hasData
                    ? _Matches(
                        widget.eventId,
                        snap.data!,
                        caption: l10n.findResultsCaption(snap.data!.length),
                      )
                    : snap.hasError
                    ? _FindError(snap.error!, onRetry: _run)
                    : _Thinking(l10n.findSearching),
              ),
            ] else ...[
              _SectionTitle(
                l10n.findRecommended,
                trailing: l10n.findFromInterests,
              ),
              ref
                  .watch(recommendationsProvider(widget.eventId))
                  .when(
                    skipLoadingOnReload: true,
                    loading: () => _Thinking(l10n.findThinking),
                    error: (e, _) => _FindError(
                      e,
                      onRetry: () => ref.invalidate(
                        recommendationsProvider(widget.eventId),
                      ),
                    ),
                    data: (m) => _Matches(widget.eventId, m, recommended: true),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// White field with a 1.5 px primary border, sparkle and a primary send button.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const noBorder = InputBorder.none;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                border: noBorder,
                enabledBorder: noBorder,
                focusedBorder: noBorder,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Material(
            color: onClear == null ? scheme.primary : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onClear ?? onSubmit,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  onClear == null ? Icons.arrow_forward : Icons.close,
                  size: 20,
                  color: onClear == null ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar fill per person, from theme colors only (stable by position in the
/// attendee list, so a person looks the same on every screen).
Color _avatarColor(BuildContext context, String personId) {
  final colors = [
    context.eho.ink,
    Theme.of(context).colorScheme.primary,
    context.eho.onLiveContainer,
  ];
  final i = demo.people.indexWhere((x) => x.id == personId);
  return colors[(i < 0 ? 0 : i) % colors.length];
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.person, {this.size = 48});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final style = size >= 64 ? t.headlineSmall : t.titleSmall;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _avatarColor(context, person.id),
        shape: BoxShape.circle,
      ),
      child: Text(
        person.initials,
        style: style?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}

/// The AI reason on a person card: 14/1.45 in body-on-tint, optional sparkle.
class _FitLine extends StatelessWidget {
  const _FitLine(this.text, {this.withIcon = true});

  final String text;
  final bool withIcon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final text = Text(
      this.text,
      style: t.bodySmall?.copyWith(height: 1.45, color: context.eho.bodyOnTint),
    );
    if (!withIcon) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.auto_awesome,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: text),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;

  /// Small caption on the right (design: "from your interests").
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(text),
      ],
    ),
  );
}

class _Matches extends StatelessWidget {
  const _Matches(
    this.eventId,
    this.matches, {
    this.recommended = false,
    this.caption,
  });

  final String eventId;
  final List<PersonMatch> matches;

  /// Line with a sparkle above the list ("3 people at ... fit").
  final String? caption;

  /// Recommendations show the sparkle before the reason; search results don't.
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(AppLocalizations.of(context).findNoMatches),
      );
    }
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    caption!,
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final (i, m) in matches.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EhoCard(
              radius: 20,
              onTap: () => context.go(
                '/e/$eventId/find/person/${m.person.id}'
                '?why=${Uri.encodeComponent(m.why)}',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Avatar(m.person),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.person.name, style: t.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              m.person.headline,
                              style: t.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (recommended && i == 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            AppLocalizations.of(context).findTopMatch,
                            style: t.labelSmall?.copyWith(
                              letterSpacing: 0,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _FitLine(m.why, withIcon: recommended),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Person detail with the Contact flow.
class PersonScreen extends ConsumerStatefulWidget {
  const PersonScreen({
    super.key,
    required this.eventId,
    required this.personId,
    this.why,
  });

  final String eventId;
  final String personId;
  final String? why;

  @override
  ConsumerState<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends ConsumerState<PersonScreen> {
  Future<void> _contact() async {
    final contacts = ref.read(contactsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      // `requested`, then `accepted` once the person accepts.
      await for (final s
          in ref
              .read(findRepositoryProvider)
              .requestContact(widget.eventId, widget.personId)) {
        contacts.set(widget.personId, s);
      }
    } on FindException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_findErrorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.eventId, widget.personId);
    // The server's contact state wins over the one saved in the app.
    ref.listen(personDetailProvider(key), (_, next) {
      final s = next.value?.contactState;
      if (s != null && s != ref.read(contactsProvider)[widget.personId]) {
        ref.read(contactsProvider.notifier).set(widget.personId, s);
      }
    });
    final detail = ref.watch(personDetailProvider(key));
    if (detail.hasError && !detail.hasValue) {
      return Scaffold(
        appBar: AppBar(),
        body: _FindError(
          detail.error!,
          onRetry: () => ref.invalidate(personDetailProvider(key)),
        ),
      );
    }
    if (!detail.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = detail.value?.person;
    if (p == null) return Scaffold(appBar: AppBar());
    final allowContact = detail.value?.allowContact ?? true;
    final state = ref.watch(contactsProvider)[p.id] ?? ContactState.none;
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final firstName = p.name.split(' ').first;
    // Deep links (and a fresh page load) carry no `?why=`: use the AI reason
    // from the recommendations when this person is among them.
    final why =
        widget.why ??
        ref
            .watch(recommendationsProvider(widget.eventId))
            .value
            ?.where((m) => m.person.id == p.id)
            .firstOrNull
            ?.why;
    // Design: no bottom navigation here (the event shell hides it); the
    // contact button and the privacy note sit at the bottom in every state.
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _BackButton(
                      onSurface: true,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/e/${widget.eventId}/find'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(child: _Avatar(p, size: 96)),
                  const SizedBox(height: 10),
                  Text(
                    p.name,
                    style: t.headlineMedium?.copyWith(fontSize: 28),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.headline,
                    style: t.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final i in p.interests) Chip(label: Text(i)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  EhoCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.lookingFor,
                            style: t.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(p.lookingFor, style: t.bodyMedium),
                        ],
                      ),
                    ),
                  ),
                  if (why != null) ...[
                    const SizedBox(height: 18),
                    EhoCard(
                      color: scheme.primaryContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 14,
                                  color: scheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.personWhyMeet,
                                  style: t.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              why,
                              style: t.bodyMedium?.copyWith(
                                color: context.eho.bodyOnTint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  switch (state) {
                    ContactState.none => FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt),
                      label: Text(l10n.personSendRequest),
                      onPressed: allowContact ? _contact : null,
                    ),
                    ContactState.requested => OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(l10n.personRequestSentTo(firstName)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      onPressed: () {},
                    ),
                    ContactState.accepted => FilledButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(l10n.personAccepted(firstName)),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.eho.ink,
                        foregroundColor: context.eho.onInk,
                      ),
                      onPressed: () =>
                          context.push('/e/${widget.eventId}/messages/${p.id}'),
                    ),
                  },
                  if (state == ContactState.none && !allowContact) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.personNotAccepting(firstName),
                      textAlign: TextAlign.center,
                      style: t.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    l10n.personDetailsNote(firstName),
                    textAlign: TextAlign.center,
                    style: t.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 44×44 round back button (white on the grey ground, grey on white headers).
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed, this.onSurface = false});

  final VoidCallback onPressed;

  /// True on the grey screen ground: the button is white; otherwise grey.
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      style: IconButton.styleFrom(
        backgroundColor: onSurface ? scheme.surface : scheme.surfaceContainer,
        foregroundColor: scheme.onSurface,
      ),
      icon: const Icon(Icons.chevron_left, size: 26),
      onPressed: onPressed,
    );
  }
}

/// MOCK messages screen (docs/MVP.md): hardcoded conversation, plus the real
/// "suggest a meeting spot" action that shows up on the Map tab.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({
    super.key,
    required this.eventId,
    required this.personId,
  });

  final String eventId;
  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (eventId, personId);
    final detail = ref.watch(personDetailProvider(key));
    if (detail.hasError && !detail.hasValue) {
      return Scaffold(
        appBar: AppBar(),
        body: _FindError(
          detail.error!,
          onRetry: () => ref.invalidate(personDetailProvider(key)),
        ),
      );
    }
    if (!detail.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = detail.value?.person;
    if (p == null) return Scaffold(appBar: AppBar());
    final spot = ref.watch(meetingSpotProvider);
    final accepted = ref.watch(contactsProvider)[p.id] == ContactState.accepted;
    final myInterests = ref.watch(profileProvider).interests;
    // "Matched on": shared interests, or theirs when the profile has none.
    final mine = p.interests.where(myInterests.contains).toList();
    final shared = [
      for (final i in mine.isEmpty ? p.interests : mine) _asTopic(i),
    ].take(2).toList();
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  _BackButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/e/$eventId/find'),
                  ),
                  const SizedBox(width: 12),
                  _Avatar(p, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: t.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          shared.isEmpty
                              ? p.headline
                              : l10n.messagesMatchedOn(
                                  shared.length == 1
                                      ? shared.first
                                      : l10n.messagesTopicsTwo(
                                          shared[0],
                                          shared[1],
                                        ),
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: scheme.surfaceContainer,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (accepted)
                      _SystemPill(
                        l10n.messagesAcceptedPill(p.name.split(' ').first),
                      ),
                    for (final (mine, text) in demo.demoMessages)
                      _Bubble(text: text, mine: mine),
                    if (spot != null && spot.personName == p.name)
                      _MeetingSpotCard(
                        place: spot.place,
                        when: _spotWhen(l10n, ref, spot),
                        onShowOnMap: () => context.go('/e/$eventId/map?spot=1'),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.messagesSuggestSpot,
                    style: IconButton.styleFrom(
                      fixedSize: const Size(48, 48),
                      backgroundColor: context.eho.liveContainer,
                      foregroundColor: context.eho.onLiveContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.place_outlined),
                    onPressed: () => _pickSpot(context, ref, p),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: l10n.messagesHint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.outline,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: scheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSpot(
    BuildContext context,
    WidgetRef ref,
    Person person,
  ) async {
    final event = ref.read(publishedEventProvider(eventId)).value;
    final places = event == null
        ? _demoPlaces
        : [
            for (final f in event.map.features)
              if (f.type != FeatureType.marker) f.name,
          ];
    final place = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final pl in places)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(pl),
              onTap: () => Navigator.pop(context, pl),
            ),
        ],
      ),
    );
    if (place == null) return;
    ref
        .read(meetingSpotProvider.notifier)
        .agree(
          eventId,
          MeetingSpot(
            personName: person.name,
            place: place,
            time: demo.demoMeetingTime,
            floor: _floorOf(ref, place),
            personId: person.id,
          ),
        );
  }

  /// Name of the map floor [place] is on: from the published map, or the
  /// demo ground floor for the demo places when the map isn't loaded.
  String? _floorOf(WidgetRef ref, String place) {
    // Only a map that is already loaded: never start loading it from here.
    final provider = publishedEventProvider(eventId);
    final map = ref.exists(provider) ? ref.read(provider).value?.map : null;
    if (map == null) {
      return _demoPlaces.contains(place) ? demo.demoFloorName : null;
    }
    final floorId = map.features
        .where((f) => f.name == place)
        .firstOrNull
        ?.floorId;
    return map.floors.where((f) => f.id == floorId).firstOrNull?.name;
  }

  /// "15:20 · Ground floor" under the meeting spot. Spots saved before these
  /// fields existed fall back to the time agreed in the (mock) conversation.
  String? _spotWhen(AppLocalizations l10n, WidgetRef ref, MeetingSpot spot) {
    final time = spot.time ?? demo.demoMeetingTime;
    final floor = spot.floor ?? _floorOf(ref, spot.place);
    return floor == null ? time : l10n.messagesSpotWhen(time, floor);
  }
}

/// Places to meet when the venue map isn't loaded (names on the seeded map).
const _demoPlaces = [...demo.stages, 'Info pult', 'Hrana i piće'];

/// An interest as a topic in a sentence: "Mobile" → "mobile", acronyms
/// ("AI / ML") stay as they are.
String _asTopic(String interest) =>
    interest.substring(1) == interest.substring(1).toLowerCase()
    ? interest.toLowerCase()
    : interest;

/// Centered system message in the conversation ("X accepted your request").
class _SystemPill extends StatelessWidget {
  const _SystemPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const big = Radius.circular(18);
    const small = Radius.circular(6);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomLeft: mine ? big : small,
            bottomRight: mine ? small : big,
          ),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.4,
            color: mine ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The agreed meeting spot: white card with a 2 px live border, pin tile,
/// place name and a "show on map" button.
class _MeetingSpotCard extends StatelessWidget {
  const _MeetingSpotCard({
    required this.place,
    required this.onShowOnMap,
    this.when,
  });

  final String place;

  /// Time and floor line ("15:20 · Ground floor").
  final String? when;
  final VoidCallback onShowOnMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: EhoCard(
          borderColor: context.eho.live,
          radius: 18,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(Icons.place_outlined, live: true, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.messagesMeetAt(place), style: t.titleSmall),
                        if (when != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            when!,
                            style: t.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  backgroundColor: scheme.surfaceContainer,
                  foregroundColor: scheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: t.labelLarge,
                ),
                onPressed: onShowOnMap,
                child: Text(
                  l10n.messagesShowOnMap,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
