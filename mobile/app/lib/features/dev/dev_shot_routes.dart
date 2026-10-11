import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../data/demo_data.dart' as demo;
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../echo/echo_paywall.dart';
import '../echo/echo_qa_sheet.dart';
import '../echo/echo_screen.dart';
import '../echo/echo_summary_screen.dart';
import '../event/event_shell.dart';
import '../find/find_screens.dart';
import '../join/join_screens.dart';
import '../organizer/organizer_screens.dart';

/// Mounts the `/dev/shot` routes. Build with `--dart-define=DEV_ROUTES=false`
/// to leave them out.
const devRoutesEnabled = bool.fromEnvironment('DEV_ROUTES', defaultValue: true);

/// Dev-only routes that open an interactive app state (sheet open, contact
/// state, seeded draft, ...) directly from a URL, so `mobile/scripts/shots.sh`
/// (which only loads pages, it cannot tap) can screenshot it.
///
/// `/dev/shot` lists every state; `/dev/shot/<state>` opens one with the demo
/// event and demo data. The states are seeded with a nested [ProviderScope]
/// (the real screens are used as they are).
List<RouteBase> devShotRoutes() => [
  GoRoute(
    path: '/dev/shot',
    builder: (c, s) => const _ShotIndex(),
    routes: [
      GoRoute(
        path: ':state',
        builder: (c, s) => _shotScreen(s.pathParameters['state']!),
      ),
    ],
  ),
];

/// A state a screenshot route can open: name and one-line description.
class DevShot {
  const DevShot(this.name, this.description, this.build);

  final String name;
  final String description;
  final Widget Function() build;
}

const _event = demoEventId;
const _session = demo.keynoteId;

/// Person on the person/messages shots (`demo.people`).
const _personId = 'p1';

final devShots = <DevShot>[
  DevShot('echo-qa', 'Echo, "Questions for the speaker" sheet open', () {
    return _EchoShot(ended: false, onReady: _openQuestions);
  }),
  DevShot('echo-qa-own', 'Echo, questions sheet with one of your own questions (q2 is seeded as yours)', () {
    return _EchoShot(ended: false, onReady: _openQuestions);
  }),
  DevShot(
    'echo-selected',
    'Echo live, a line selected ("Ask about this") and an AI answer inline',
    () => _EchoShot(
      ended: false,
      // The second-to-last line; the answer lands below it.
      selectLine: demo.keynoteTranscript.length - 2,
      ask: 'What is the main advice of the talk?',
    ),
  ),
  DevShot('echo-paywall', 'Echo, ended, "Missed something?" paywall sheet', () {
    return _EchoShot(
      ended: true,
      onReady: (c) => showEchoPaywall(c, eventId: _event, sessionId: _session),
    );
  }),
  DevShot(
    'echo-summary',
    'Echo full summary page (after unlock)',
    () => const _EchoSummaryShot(),
  ),
  DevShot(
    'echo-translated',
    'Echo live, translate on',
    () => const _EchoShot(ended: false, translated: true),
  ),
  DevShot(
    'echo-ended',
    'Echo after the talk, summary card locked',
    () => const _EchoShot(ended: true),
  ),
  DevShot(
    'echo-ended-unlocked',
    'Echo after the talk, summary card unlocked',
    () => const _EchoShot(ended: true, unlocked: true),
  ),
  DevShot(
    'person-none',
    'Person (in event tabs), no contact yet',
    () => const _PersonShot(ContactState.none),
  ),
  DevShot(
    'person-pending',
    'Person, contact request sent',
    () => const _PersonShot(ContactState.requested),
  ),
  DevShot(
    'person-connected',
    'Person, connected',
    () => const _PersonShot(ContactState.accepted),
  ),
  DevShot(
    'messages-spot',
    'Messages with a meeting-spot card',
    () => const _MessagesShot(),
  ),
  DevShot(
    'find-results',
    'Find tab with results for a sample prompt',
    () => const _FindShot(),
  ),
  DevShot(
    'myevents-live',
    'My events with the live card',
    () => const _MyEventsShot(),
  ),
  DevShot(
    'organizer-review',
    'Organizer review, draft with a flagged empty-stage row',
    () => const _OrganizerReviewShot(),
  ),
  DevShot(
    'organizer-upload-files',
    'Organizer upload, three files chosen',
    () => OrganizerUploadScreen(initialFiles: _uploadedFiles),
  ),
  DevShot(
    'organizer-upload-progress',
    'Organizer upload, extraction progress ("Found 3 stages, 6 sessions, ...")',
    () => OrganizerUploadScreen(
      initialFiles: _uploadedFiles,
      foundSoFar: _foundSoFar,
      progress: 0.62,
    ),
  ),
  DevShot(
    'organizer-published',
    'Organizer published (link + QR)',
    () => OrganizerPublishedScreen(
      url: '${linkBase()}/e/$_event',
      name: demo.demoEventName,
    ),
  ),
];

Widget _shotScreen(String name) {
  for (final s in devShots) {
    if (s.name == name) return s.build();
  }
  return _ShotIndex(unknown: name);
}

// -------------------------------------------------------------------- index

class _ShotIndex extends StatelessWidget {
  const _ShotIndex({this.unknown});

  final String? unknown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Screenshot states')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (unknown != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Unknown state "$unknown".',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          for (final s in devShots)
            ListTile(
              title: Text('/dev/shot/${s.name}'),
              subtitle: Text(s.description),
              onTap: () => context.go('/dev/shot/${s.name}'),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------- Echo

/// Echo with the whole keynote transcript delivered at once. It never ends
/// unless [ended]. Real demo data for everything else.
class _ShotEchoRepository extends DemoEchoRepository {
  _ShotEchoRepository({required this.ended});

  final bool ended;

  @override
  Stream<List<TranscriptLine>> transcript(String eventId, String sessionId) =>
      Stream<List<TranscriptLine>>.multi((c) {
        c.add(demo.keynoteTranscript);
        if (ended) c.close();
      });
}

class _Unlocked extends UnlockedNotifier {
  @override
  Set<String> build() => {_session};
}

/// The Echo screen over [_ShotEchoRepository]; [onReady] runs once it has
/// been on screen for a moment (to open a sheet).
class _EchoShot extends StatelessWidget {
  const _EchoShot({
    required this.ended,
    this.translated = false,
    this.unlocked = false,
    this.selectLine,
    this.ask,
    this.onReady,
  });

  final bool ended;
  final bool translated;
  final bool unlocked;
  final int? selectLine;
  final String? ask;
  final void Function(BuildContext context)? onReady;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      echoRepositoryProvider.overrideWithValue(
        _ShotEchoRepository(ended: ended),
      ),
      if (unlocked) unlockedSummariesProvider.overrideWith(_Unlocked.new),
    ],
    child: _AfterFirstFrame(
      run: onReady,
      child: EchoScreen(
        eventId: _event,
        sessionId: _session,
        startTranslated: translated,
        devSelectLine: selectLine,
        devAsk: ask,
      ),
    ),
  );
}

/// Calls [run] shortly after the first frame, so the screen behind a sheet
/// has loaded.
class _AfterFirstFrame extends StatefulWidget {
  const _AfterFirstFrame({required this.run, required this.child});

  final void Function(BuildContext context)? run;
  final Widget child;

  @override
  State<_AfterFirstFrame> createState() => _AfterFirstFrameState();
}

class _AfterFirstFrameState extends State<_AfterFirstFrame> {
  @override
  void initState() {
    super.initState();
    final run = widget.run;
    if (run == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) run(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens the questions sheet with the seeded demo questions as they are
/// (the second one is yours and voted).
Future<void> _openQuestions(BuildContext context) async {
  final repo = ProviderScope.containerOf(context).read(echoRepositoryProvider);
  final loaded = await repo.questions(_event, _session);
  if (!context.mounted) return;
  final questions = ValueNotifier<List<SpeakerQuestion>>(loaded);
  final name = demo.sessions
      .where((s) => s.id == _session)
      .firstOrNull
      ?.speakers
      .firstOrNull
      ?.name
      .split(' ')
      .first;
  await showEchoQuestions(
    context,
    questions: questions,
    speakerName: name,
    onVote: (_) {},
    onAsk: (_) async => null,
  );
}

class _EchoSummaryShot extends StatelessWidget {
  const _EchoSummaryShot();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      echoRepositoryProvider.overrideWithValue(
        _ShotEchoRepository(ended: true),
      ),
      unlockedSummariesProvider.overrideWith(_Unlocked.new),
    ],
    child: EchoSummaryScreen(
      eventId: _event,
      sessionId: _session,
      session: demo.sessions.where((s) => s.id == _session).firstOrNull,
      // Every time links to a line, as when the transcript is loaded.
      lineAt: (seconds) => 0,
    ),
  );
}

// ------------------------------------------------------------ People / Find

class _Contact extends ContactsNotifier {
  _Contact(this.state0);

  final ContactState state0;

  @override
  Map<String, ContactState> build() => {_personId: state0};
}

class _Spot extends MeetingSpotNotifier {
  @override
  MeetingSpot? build() => MeetingSpot(
    personName: demo.people.firstWhere((p) => p.id == _personId).name,
    place: 'Info pult',
    time: demo.demoMeetingTime,
    floor: demo.demoFloorName,
  );
}

/// [child] inside the event bottom navigation, like the real tab routes.
Widget _inShell(String location, Widget child) =>
    EventShell(eventId: _event, location: location, child: child);

class _PersonShot extends StatelessWidget {
  const _PersonShot(this.contact);

  final ContactState contact;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [contactsProvider.overrideWith(() => _Contact(contact))],
    child: _inShell(
      '/e/$_event/find/person/$_personId',
      PersonScreen(
        eventId: _event,
        personId: _personId,
        why: demo.fitLines[_personId],
      ),
    ),
  );
}

class _MessagesShot extends StatelessWidget {
  const _MessagesShot();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      contactsProvider.overrideWith(() => _Contact(ContactState.accepted)),
      meetingSpotProvider.overrideWith(_Spot.new),
    ],
    child: const MessagesScreen(eventId: _event, personId: _personId),
  );
}

class _FindShot extends StatelessWidget {
  const _FindShot();

  @override
  Widget build(BuildContext context) => _inShell(
    '/e/$_event/find',
    const FindScreen(eventId: _event, initialPrompt: 'On-device ML on Android'),
  );
}

// ------------------------------------------------------- My events / organizer

class _JoinedDemo extends JoinedEventsNotifier {
  @override
  List<EventSummary> build() => const [
    EventSummary(
      id: _event,
      name: demo.demoEventName,
      dates: demo.demoEventDates,
      venue: demo.demoEventVenue,
    ),
    demo.pastEvent,
  ];
}

class _MyEventsShot extends StatelessWidget {
  const _MyEventsShot();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [joinedEventsProvider.overrideWith(_JoinedDemo.new)],
    child: const MyEventsScreen(),
  );
}

/// The files on the upload shots (the design's three).
const _uploadedFiles = [
  UploadedFile(name: 'devfest-agenda-final-v3.pdf', sizeBytes: 412 * 1024),
  UploadedFile(name: 'speakers.xlsx', sizeBytes: 38 * 1024),
  UploadedFile(name: 'sava-centar-ground-floor.png', sizeBytes: 1258291),
];

/// What the extraction has found so far on the progress shot: 3 stages,
/// 6 sessions, 6 speakers (as in the design).
final _foundSoFar = EventDraft(
  name: demo.demoEventName,
  dates: demo.demoEventDates,
  venue: demo.demoEventVenue,
  stages: demo.stages,
  sessions: demo.sessions.take(6).toList(),
  speakers: demo.speakers,
);

class _FileCount extends OrganizerFileCountNotifier {
  @override
  int build() => _uploadedFiles.length;
}

/// The demo draft with one session without a stage (a flagged row).
class _FlaggedDraft extends DraftNotifier {
  @override
  EventDraft? build() {
    final sessions = demo.sessions.where((s) => !s.isBreak).toList();
    final i = sessions.indexWhere(
      (s) => s.id == demo.organizerFlaggedSessionId,
    );
    final s = sessions[i < 0 ? 0 : i];
    sessions[i < 0 ? 0 : i] = Session(
      id: s.id,
      title: s.title,
      stage: '',
      start: s.start,
      end: s.end,
      speakers: s.speakers,
      description: s.description,
      track: s.track,
      isLive: s.isLive,
    );
    return EventDraft(
      name: demo.demoEventName,
      dates: demo.demoEventDates,
      venue: demo.demoEventVenue,
      stages: demo.stages,
      sessions: sessions,
      speakers: demo.speakers,
    );
  }
}

class _OrganizerReviewShot extends StatelessWidget {
  const _OrganizerReviewShot();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      organizerDraftProvider.overrideWith(_FlaggedDraft.new),
      organizerFileCountProvider.overrideWith(_FileCount.new),
    ],
    child: const OrganizerReviewScreen(),
  );
}
