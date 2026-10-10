import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
import '../agenda/agenda_screens.dart';

/// Echo: one screen per talk. Live transcript in the middle; a "catch up"
/// summary on top (becomes the premium full summary when the talk ends);
/// one input at the bottom with two modes: Ask AI / Ask speaker.
class EchoScreen extends ConsumerStatefulWidget {
  const EchoScreen({super.key, required this.eventId, required this.sessionId});

  final String eventId;
  final String sessionId;

  @override
  ConsumerState<EchoScreen> createState() => _EchoScreenState();
}

enum _Mode { ai, speaker }

/// Items shown in the transcript column besides spoken lines.
sealed class _Entry {}

class _Line extends _Entry {
  _Line(this.line, this.index);
  final TranscriptLine line;
  final int index;
}

class _Answer extends _Entry {
  _Answer(this.question);
  final String question;
  String? answer;
  Object? error;
}

/// Target of the translate toggle ("Translate to Serbian").
const _translateTo = 'sr';

/// User-facing text for a failed Echo call.
String _errorText(AppLocalizations l10n, Object error) =>
    switch (error is EchoException ? error.kind : EchoErrorKind.failed) {
      EchoErrorKind.aiBusy => l10n.echoErrorAiBusy,
      EchoErrorKind.rateLimited => l10n.echoErrorRateLimited,
      EchoErrorKind.offline => l10n.echoErrorOffline,
      EchoErrorKind.noTranscript => l10n.echoErrorNoTranscript,
      EchoErrorKind.failed => l10n.echoErrorFailed,
    };

class _EchoScreenState extends ConsumerState<EchoScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  final _entries = <_Entry>[];
  final _answers = <_Answer>[];
  final _questions = ValueNotifier<List<SpeakerQuestion>>([]);
  String? _catchUp;
  Object? _catchUpError;
  bool _catchUpLoading = false;
  Object? _transcriptError;
  bool _translate = false;
  final _translations = <int, String>{};
  int _translatedTo = 0; // first line index without a translation
  bool _translating = false;
  bool _ended = false;
  _Mode _mode = _Mode.ai;
  int _lineCount = 0;

  /// Auto-scroll follows new lines only while the user is at the bottom.
  /// Scrolling up pauses it and shows "Jump to live".
  bool _atBottom = true;
  int _autoScrolls = 0; // in-flight programmatic scrolls

  EchoRepository get _repo => ref.read(echoRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _repo
        .transcript(widget.eventId, widget.sessionId)
        .listen(
          (lines) {
            if (!mounted) return;
            setState(() {
              _transcriptError = null;
              if (lines.length < _lineCount) {
                // The transcript restarted (a new replay): start over.
                _entries.removeWhere((e) => e is _Line);
                _translations.clear();
                _translatedTo = 0;
                _lineCount = 0;
              }
              for (final l in lines.skip(_lineCount)) {
                _entries.add(_Line(l, _lineCount++));
              }
            });
            _toBottom();
            _translateMore();
          },
          onError: (Object e) {
            if (mounted) setState(() => _transcriptError = e);
          },
          onDone: () {
            if (mounted) setState(() => _ended = true);
          },
        );
    _loadCatchUp();
    _loadQuestions();
  }

  Future<void> _loadCatchUp() async {
    if (_catchUpLoading) return;
    setState(() {
      _catchUpLoading = true;
      _catchUpError = null;
    });
    try {
      final s = await _repo.catchUp(widget.eventId, widget.sessionId);
      if (mounted) setState(() => _catchUp = s);
    } catch (e) {
      if (mounted) setState(() => _catchUpError = e);
    } finally {
      if (mounted) setState(() => _catchUpLoading = false);
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final q = await _repo.questions(widget.eventId, widget.sessionId);
      if (mounted) setState(() => _questions.value = q);
    } catch (_) {
      // Keep what we have; the sheet reloads when opened.
    }
  }

  void _setQuestion(String id, SpeakerQuestion q) {
    if (!mounted) return;
    setState(() {
      _questions.value = [for (final x in _questions.value) x.id == id ? q : x];
    });
  }

  Future<void> _vote(SpeakerQuestion q) async {
    final up = !q.voted;
    _setQuestion(
      q.id,
      SpeakerQuestion(
        id: q.id,
        text: q.text,
        votes: q.votes + (up ? 1 : (q.votes > 0 ? -1 : 0)),
        mine: q.mine,
        voted: up,
      ),
    );
    try {
      final updated = await _repo.vote(
        widget.eventId,
        widget.sessionId,
        q,
        up: up,
      );
      _setQuestion(q.id, updated);
    } catch (e) {
      _setQuestion(q.id, q);
      _showError(e);
    }
  }

  /// Fetches translations for lines that don't have one yet, while the
  /// translate toggle is on. Runs again as new lines arrive.
  Future<void> _translateMore() async {
    if (!_translate || _translating || _translatedTo >= _lineCount) return;
    _translating = true;
    final from = _translatedTo;
    var progressed = false;
    try {
      final r = await _repo.translate(
        widget.eventId,
        widget.sessionId,
        language: _translateTo,
        fromIndex: from,
      );
      if (!mounted) return;
      progressed = r.nextIndex > from;
      setState(() {
        _translations.addAll(r.lines);
        if (progressed) _translatedTo = r.nextIndex;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _translate = false);
      _showError(e);
    } finally {
      _translating = false;
    }
    if (progressed) _translateMore();
  }

  void _toggleTranslate() {
    setState(() => _translate = !_translate);
    _translateMore();
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_errorText(AppLocalizations.of(context), e))),
    );
  }

  @override
  void dispose() {
    _questions.dispose();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls to the newest entry, unless the user scrolled up (then pass
  /// [force] to resume following).
  void _toBottom({bool force = false}) {
    if (force) setState(() => _atBottom = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if ((!_atBottom && !force) || !_scroll.hasClients) return;
      _autoScrolls++;
      try {
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } finally {
        _autoScrolls--;
      }
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (_autoScrolls > 0 || n.depth != 0) return false;
    final atBottom = n.metrics.extentAfter < 48;
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
    return false;
  }

  void _askAbout(TranscriptLine line) {
    setState(() => _mode = _Mode.ai);
    _input.text = AppLocalizations.of(context).echoAskAboutPrefill(line.text);
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    if (_mode == _Mode.speaker && preset == null) {
      final SpeakerQuestion q;
      try {
        q = await _repo.submitQuestion(widget.eventId, widget.sessionId, text);
      } catch (e) {
        if (_input.text.isEmpty) _input.text = text; // don't lose it
        _showError(e);
        return;
      }
      if (!mounted) return;
      setState(() => _questions.value = [q, ..._questions.value]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).echoQuestionSent)),
      );
      return;
    }
    final a = _Answer(text);
    setState(() {
      _entries.add(a);
      _answers.add(a);
    });
    _toBottom(force: true);
    await _runAsk(a);
  }

  Future<void> _runAsk(_Answer a) async {
    if (a.error != null) setState(() => a.error = null);
    try {
      final answer = await _repo.ask(
        widget.eventId,
        widget.sessionId,
        a.question,
      );
      if (!mounted) return;
      setState(() => a.answer = answer);
    } catch (e) {
      if (!mounted) return;
      setState(() => a.error = e);
    }
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(agendaProvider(widget.eventId)).value ?? [];
    final session = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          session?.title ?? l10n.echoTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _translate ? l10n.echoShowOriginal : l10n.echoTranslate,
            icon: Icon(
              Icons.translate,
              color: _translate ? scheme.primary : null,
            ),
            onPressed: _toggleTranslate,
          ),
        ],
      ),
      body: Column(
        children: [
          _SummaryStrip(
            sessionId: widget.sessionId,
            eventId: widget.eventId,
            catchUp: _catchUp,
            catchUpError: _catchUpLoading || _catchUpError == null
                ? null
                : _errorText(l10n, _catchUpError!),
            onCatchUp: _loadCatchUp,
            ended: _ended,
          ),
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _entries.length + (_ended ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _entries.length) return const _EndedMarker();
                      return switch (_entries[i]) {
                        _Line(:final line, :final index) => _TranscriptRow(
                          line: line,
                          translated: _translate
                              ? _translations[index] ??
                                    (line.translated.isNotEmpty
                                        ? line.translated
                                        : null)
                              : null,
                          onAsk: () => _askAbout(line),
                        ),
                        final _Answer a => _AnswerCard(
                          a.question,
                          a.answer,
                          error: a.error == null
                              ? null
                              : _errorText(l10n, a.error!),
                          onRetry: () => _runAsk(a),
                        ),
                      };
                    },
                  ),
                ),
                if (_entries.isEmpty && !_ended)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _transcriptError == null
                            ? l10n.echoWaitingForTalk
                            : l10n.echoTranscriptUnavailable,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                if (!_atBottom)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: Text(l10n.echoJumpToLive),
                      onPressed: () => _toBottom(force: true),
                    ),
                  ),
              ],
            ),
          ),
          _Composer(
            controller: _input,
            focusNode: _inputFocus,
            mode: _mode,
            questionCount: _questions.value.length,
            onMode: (m) => setState(() => _mode = m),
            onSend: _send,
            onOpenQuestions: () => _showQuestions(context),
          ),
        ],
      ),
    );
  }

  void _showQuestions(BuildContext context) {
    _loadQuestions(); // pick up others' questions and votes
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => ValueListenableBuilder<List<SpeakerQuestion>>(
        valueListenable: _questions,
        builder: (context, questions, _) {
          final sorted = [...questions]
            ..sort((a, b) => b.votes.compareTo(a.votes));
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            builder: (context, scroll) => ListView(
              controller: scroll,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    AppLocalizations.of(context).echoQuestionsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final q in sorted)
                  ListTile(
                    title: Text(q.text),
                    subtitle: q.mine
                        ? Text(AppLocalizations.of(context).echoYourQuestion)
                        : null,
                    trailing: q.voted
                        ? FilledButton.tonalIcon(
                            icon: const Icon(Icons.arrow_upward),
                            label: Text('${q.votes}'),
                            onPressed: () => _vote(q),
                          )
                        : TextButton.icon(
                            icon: const Icon(Icons.arrow_upward),
                            label: Text('${q.votes}'),
                            onPressed: () => _vote(q),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends ConsumerWidget {
  const _SummaryStrip({
    required this.eventId,
    required this.sessionId,
    required this.catchUp,
    required this.catchUpError,
    required this.onCatchUp,
    required this.ended,
  });

  final String eventId;
  final String sessionId;
  final String? catchUp;
  final String? catchUpError;

  /// (Re)loads the catch-up: on expand, so it covers the talk so far.
  final VoidCallback onCatchUp;
  final bool ended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    if (ended) {
      final unlocked = ref.watch(unlockedSummariesProvider).contains(sessionId);
      return Material(
        color: scheme.tertiaryContainer,
        child: ListTile(
          leading: Icon(unlocked ? Icons.summarize : Icons.lock_outline),
          title: Text(l10n.echoFullSummary),
          subtitle: Text(
            unlocked ? l10n.echoUnlocked : l10n.echoPremiumSubtitle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openSummary(context, ref, unlocked),
        ),
      );
    }
    return Material(
      color: scheme.surfaceContainerHigh,
      child: ExpansionTile(
        leading: const Icon(Icons.bolt),
        title: Text(l10n.echoCatchUp),
        subtitle: Text(l10n.echoCatchUpSubtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (open) {
          if (open) onCatchUp();
        },
        children: [
          if (catchUpError != null) ...[
            Text(catchUpError!),
            TextButton(onPressed: onCatchUp, child: Text(l10n.echoRetry)),
          ] else
            Text(catchUp ?? l10n.echoSummarizing),
        ],
      ),
    );
  }

  Future<void> _openSummary(
    BuildContext context,
    WidgetRef ref,
    bool unlocked,
  ) async {
    if (!unlocked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            icon: const Icon(Icons.workspace_premium),
            title: Text(l10n.echoUnlockTitle),
            content: Text(l10n.echoUnlockBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.echoNotNow),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.echoUnlockPrice),
              ),
            ],
          );
        },
      );
      if (ok != true) return;
      ref.read(unlockedSummariesProvider.notifier).unlock(sessionId);
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, scroll) => _SummarySheet(
          eventId: eventId,
          sessionId: sessionId,
          scroll: scroll,
        ),
      ),
    );
  }
}

/// Full summary with a loading state and "Try again" on failure.
class _SummarySheet extends ConsumerStatefulWidget {
  const _SummarySheet({
    required this.eventId,
    required this.sessionId,
    required this.scroll,
  });

  final String eventId;
  final String sessionId;
  final ScrollController scroll;

  @override
  ConsumerState<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<_SummarySheet> {
  late Future<String> _summary = _load();

  Future<String> _load() => ref
      .read(echoRepositoryProvider)
      .fullSummary(widget.eventId, widget.sessionId);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<String>(
      future: _summary,
      builder: (context, snap) => ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.all(24),
        children: [
          if (snap.hasError) ...[
            Text(_errorText(l10n, snap.error!), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _summary = _load()),
                child: Text(l10n.echoRetry),
              ),
            ),
          ] else if (!snap.hasData) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            Text(l10n.echoThinking, textAlign: TextAlign.center),
          ] else
            Text(snap.data!, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _TranscriptRow extends StatelessWidget {
  const _TranscriptRow({
    required this.line,
    required this.translated,
    required this.onAsk,
  });

  final TranscriptLine line;

  /// Shown instead of the original when set (translate on and translated).
  final String? translated;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final m = (line.atSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (line.atSeconds % 60).toString().padLeft(2, '0');
    return InkWell(
      onLongPress: () async {
        // Anchor a small "Ask about this" menu to the pressed row.
        final box = context.findRenderObject() as RenderBox;
        final overlay =
            Overlay.of(context).context.findRenderObject() as RenderBox;
        final rect = Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(
            box.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        );
        final ask = await showMenu<bool>(
          context: context,
          position: RelativeRect.fromRect(
            Rect.fromLTWH(rect.left + 48, rect.bottom - 8, 0, 0),
            Offset.zero & overlay.size,
          ),
          items: [
            PopupMenuItem(
              value: true,
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(AppLocalizations.of(context).echoAskAboutThis),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
        if (ask == true) onAsk();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 48, child: Text('$m:$s', style: t.labelSmall)),
            Expanded(child: Text(translated ?? line.text, style: t.bodyLarge)),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard(
    this.question,
    this.answer, {
    required this.error,
    required this.onRetry,
  });

  final String question;
  final String? answer;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(question, style: t.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            if (error != null) ...[
              Text(error!, style: t.bodyMedium),
              TextButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context).echoRetry),
              ),
            ] else if (answer == null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).echoThinking,
                style: t.bodySmall,
              ),
            ] else
              Text(answer!, style: t.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EndedMarker extends StatelessWidget {
  const _EndedMarker();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            AppLocalizations.of(context).echoTalkEnded,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.mode,
    required this.questionCount,
    required this.onMode,
    required this.onSend,
    required this.onOpenQuestions,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final _Mode mode;
  final int questionCount;
  final ValueChanged<_Mode> onMode;
  final Future<void> Function([String?]) onSend;
  final VoidCallback onOpenQuestions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_Mode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: _Mode.ai,
                          label: Text(l10n.echoAskAi),
                        ),
                        ButtonSegment(
                          value: _Mode.speaker,
                          label: Text(l10n.echoAskSpeaker),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => onMode(s.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: l10n.echoQuestionsTitle,
                    onPressed: onOpenQuestions,
                    icon: Badge.count(
                      count: questionCount,
                      child: const Icon(Icons.forum_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: mode == _Mode.ai
                      ? l10n.echoAskHint
                      : l10n.echoSpeakerHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => onSend(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
