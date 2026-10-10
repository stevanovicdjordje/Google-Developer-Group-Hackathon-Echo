import 'package:eho_maps/eho_maps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/demo_data.dart' as demo;
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

final recommendationsProvider =
    FutureProvider.family<List<PersonMatch>, String>((ref, eventId) {
      final me = ref.watch(profileProvider);
      return ref.watch(findRepositoryProvider).recommendations(eventId, me);
    });

/// Find tab: AI recommendations, or describe who you want to meet.
class FindScreen extends ConsumerStatefulWidget {
  const FindScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends ConsumerState<FindScreen> {
  final _prompt = TextEditingController();
  Future<List<PersonMatch>>? _search;
  String _lastPrompt = '';

  void _run() {
    final p = _prompt.text.trim();
    if (p.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _lastPrompt = p;
      _search = ref.read(findRepositoryProvider).search(widget.eventId, p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.findTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _prompt,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                hintText: l10n.findSearchHint,
                prefixIcon: const Icon(Icons.auto_awesome),
                border: const OutlineInputBorder(),
                suffixIcon: _search == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search = null;
                          _prompt.clear();
                        }),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_search != null) ...[
            _SectionTitle(l10n.findResultsFor(_lastPrompt), t),
            FutureBuilder<List<PersonMatch>>(
              future: _search,
              builder: (context, snap) => snap.hasData
                  ? _Matches(widget.eventId, snap.data!)
                  : _Thinking(l10n.findSearching),
            ),
          ] else ...[
            _SectionTitle(l10n.findRecommended, t),
            ref
                .watch(recommendationsProvider(widget.eventId))
                .when(
                  loading: () => _Thinking(l10n.findThinking),
                  error: (e, _) => Text('$e'),
                  data: (m) => _Matches(widget.eventId, m),
                ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, this.t);

  final String text;
  final TextTheme t;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(text, style: t.titleMedium),
  );
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
  const _Matches(this.eventId, this.matches);

  final String eventId;
  final List<PersonMatch> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(AppLocalizations.of(context).findNoMatches),
      );
    }
    return Column(
      children: [
        for (final m in matches)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(child: Text(m.person.initials)),
              title: Text(m.person.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.person.headline),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(m.why)),
                    ],
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () => context.go(
                '/e/$eventId/find/person/${m.person.id}'
                '?why=${Uri.encodeComponent(m.why)}',
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
    await ref
        .read(findRepositoryProvider)
        .requestContact(widget.eventId, widget.personId);
    contacts.set(widget.personId, ContactState.requested);
    // Demo: the other person accepts shortly after.
    await Future<void>.delayed(const Duration(seconds: 2));
    contacts.set(widget.personId, ContactState.accepted);
  }

  @override
  Widget build(BuildContext context) {
    final p = demo.people.where((x) => x.id == widget.personId).firstOrNull;
    if (p == null) return Scaffold(appBar: AppBar());
    final state = ref.watch(contactsProvider)[p.id] ?? ContactState.none;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(radius: 40, child: Text(p.initials, style: t.headlineSmall)),
          const SizedBox(height: 16),
          Text(p.name, style: t.headlineSmall, textAlign: TextAlign.center),
          Text(p.headline, style: t.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [for (final i in p.interests) Chip(label: Text(i))],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(l10n.lookingFor),
            subtitle: Text(p.lookingFor),
          ),
          if (widget.why != null)
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(l10n.personWhyMeet),
              subtitle: Text(widget.why!),
            ),
          const SizedBox(height: 24),
          switch (state) {
            ContactState.none => FilledButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.personSendRequest),
              onPressed: _contact,
            ),
            ContactState.requested => FilledButton(
              onPressed: null,
              child: Text(l10n.personRequestSent),
            ),
            ContactState.accepted => FilledButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.personAccepted(p.name.split(' ').first)),
              onPressed: () =>
                  context.push('/e/${widget.eventId}/messages/${p.id}'),
            ),
          },
        ],
      ),
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
    final p = demo.people.firstWhere((x) => x.id == personId);
    final spot = ref.watch(meetingSpotProvider);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (mine, text) in demo.demoMessages)
                  _Bubble(text: text, mine: mine),
                if (spot != null && spot.personName == p.name)
                  _Bubble(
                    text: l10n.messagesMeetAt(spot.place),
                    mine: true,
                    color: scheme.tertiaryContainer,
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: l10n.messagesSuggestSpot,
                    icon: const Icon(Icons.place_outlined),
                    onPressed: () => _pickSpot(context, ref, p.name),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: l10n.messagesHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSpot(
    BuildContext context,
    WidgetRef ref,
    String personName,
  ) async {
    final event = ref.read(publishedEventProvider(eventId)).value;
    final places = event == null
        ? [...demo.stages, 'Info pult', 'Hrana i piće']
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
        .set(MeetingSpot(personName: personName, place: place));
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.mine, this.color});

  final String text;
  final bool mine;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: color ??
              (mine ? scheme.primaryContainer : scheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text),
      ),
    );
  }
}
