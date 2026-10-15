import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/ui.dart';
import '../../data/app_state.dart';
import '../../data/echo_models.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
import '../agenda/agenda_screens.dart';
import 'echo_errors.dart';
import 'echo_paywall.dart';
import 'echo_qa_sheet.dart';
import 'echo_summary_screen.dart';

/// Echo: one screen per talk. Live transcript in the middle; a "catch up"
/// summary on top (becomes the premium full summary when the talk ends);
/// one input at the bottom with two modes: Ask AI / Ask speaker.
class EchoScreen extends ConsumerStatefulWidget {
  const EchoScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
    this.startTranslated = false,
    this.devSelectLine,
    this.devAsk,
    this.initialQuestion,
    this.startScrolledUp = false,
  });

  final String eventId;
  final String sessionId;

  /// Opens with translate already on (dev screenshot routes only).
  final bool startTranslated;

  /// Index of a transcript line to highlight once it has loaded, and a
  /// question to ask the AI right after (dev screenshot routes only).
  final int? devSelectLine;
  final String? devAsk;

  /// Asks the AI this question once the transcript has loaded, without
  /// selecting a line (dev screenshot routes only).
  final String? initialQuestion;

  /// Scrolls the transcript to the top once loaded, so "Jump to live" shows
  /// (dev screenshot routes only).
  final bool startScrolledUp;

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

/// Target of the translate toggle ("Translate to Serbian"). While it is on,
/// catch-up, Ask answers and the full summary are requested in it too.
const _translateTo = 'sr';

/// A summary timestamp jumps to the transcript line within this many
/// seconds of it (the server always points at a real line's start).
const _jumpTolerance = 10;

const _errorText = echoErrorText;

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
  int _catchUpRequest = 0; // only the newest request's result is shown
  Object? _transcriptError;
  late bool _translate = widget.startTranslated;
  final _translations = <int, String>{};
  int _translatedTo = 0; // first line index without a translation
  bool _translating = false;
  bool _ended = false;
  _Mode _mode = _Mode.ai;
  int _lineCount = 0;

  /// Line index tapped/long-pressed: highlighted with "Ask about this".
  int? _selected;
  bool _paywallShown = false; // auto-opened once when the talk ends
  int _updates = 0; // transcript snapshots received
  bool _devApplied = false; // devSelectLine/devAsk done

  /// Auto-scroll follows new lines only while the user is at the bottom.
  /// Scrolling up pauses it and shows "Jump to live".
  bool _atBottom = true;
  int _autoScrolls = 0; // in-flight programmatic scrolls

  /// On the selected line's row, to scroll it into view.
  final _selectedKey = GlobalKey();

  EchoRepository get _repo => ref.read(echoRepositoryProvider);

  /// Language of AI text (catch-up, answers, summary).
  String get _language => _translate ? _translateTo : 'en';

  @override
  void initState() {
    super.initState();
    _repo
        .transcript(widget.eventId, widget.sessionId)
        .listen(
          (lines) {
            if (!mounted) return;
            _updates++;
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
            _applyDevStart();
          },
          onError: (Object e) {
            if (mounted) setState(() => _transcriptError = e);
          },
          onDone: () {
            if (!mounted) return;
            setState(() => _ended = true);
            // A talk that was already over when opened arrives in one go:
            // read it from the top, under the summary banner, not from the
            // end with the first visible line cut by the banner.
            if (_updates <= 1) _toTop();
            _offerSummary();
          },
        );
    _loadCatchUp();
    _loadQuestions();
  }

  /// Dev screenshot routes: select a line and ask a question, once.
  void _applyDevStart() {
    if (!_devApplied &&
        _lineCount > 0 &&
        (widget.initialQuestion != null || widget.startScrolledUp)) {
      _devApplied = true;
      final q = widget.initialQuestion;
      if (q != null) _send(q);
      if (widget.startScrolledUp) {
        setState(() => _atBottom = false);
        _toTop();
      }
      return;
    }
    final at = widget.devSelectLine;
    if (_devApplied || at == null || _lineCount <= at) return;
    _devApplied = true;
    setState(() => _selected = at);
    final ask = widget.devAsk;
    if (ask != null) _send(ask);
  }

  /// Loads the catch-up in the current language; [force] starts over even
  /// while a request is running (after the language changed).
  Future<void> _loadCatchUp({bool force = false}) async {
    if (_catchUpLoading && !force) return;
    final id = ++_catchUpRequest;
    setState(() {
      _catchUpLoading = true;
      _catchUpError = null;
    });
    bool current() => mounted && id == _catchUpRequest;
    try {
      final s = await _repo.catchUp(
        widget.eventId,
        widget.sessionId,
        language: _language,
      );
      if (current()) setState(() => _catchUp = s);
    } catch (e) {
      if (current()) setState(() => _catchUpError = e);
    } finally {
      if (current()) setState(() => _catchUpLoading = false);
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
        mergedCount: q.mergedCount,
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
    setState(() {
      _translate = !_translate;
      _catchUp = null; // it was in the other language
    });
    _translateMore();
    if (!_ended) _loadCatchUp(force: true);
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

  void _toTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _atBottom = false;
      _scroll.jumpTo(0);
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (_autoScrolls > 0 || n.depth != 0) return false;
    final atBottom = n.metrics.extentAfter < 48;
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
    return false;
  }

  void _askAbout(TranscriptLine line) {
    setState(() {
      _mode = _Mode.ai;
      _selected = null;
    });
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
      final sent = await _submitQuestion(text);
      if (sent == null) {
        if (_input.text.isEmpty) _input.text = text; // don't lose it
        return;
      }
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent.merged ? l10n.echoQuestionMerged : l10n.echoQuestionSent,
          ),
        ),
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
        language: _language,
      );
      if (!mounted) return;
      setState(() => a.answer = answer);
    } catch (e) {
      if (!mounted) return;
      setState(() => a.error = e);
    }
    _toBottom();
  }

  /// Sends a question to the speaker; null when it failed. A question the
  /// server merged into a similar one comes back as that one (now yours,
  /// with your vote): it replaces the old entry and moves to the top.
  Future<QuestionSubmission?> _submitQuestion(String text) async {
    try {
      final sent = await _repo.submitQuestion(
        widget.eventId,
        widget.sessionId,
        text,
      );
      final q = sent.question;
      if (mounted) {
        setState(
          () => _questions.value = [
            q,
            for (final x in _questions.value)
              if (x.id != q.id) x,
          ],
        );
      }
      return sent;
    } catch (e) {
      _showError(e);
      return null;
    }
  }

  /// When the talk ends while the user follows it: open the paywall once
  /// (unless already unlocked). Not when Echo is opened after the talk
  /// (the whole transcript arrives in one snapshot).
  void _offerSummary() {
    if (_paywallShown || _unlocked || _updates < 2) return;
    _paywallShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openSummary();
    });
  }

  bool get _unlocked =>
      ref.read(unlockedSummariesProvider).contains(widget.sessionId);

  /// Paywall first if needed, then the summary page.
  Future<void> _openSummary() async {
    if (!_unlocked) {
      final ok = await showEchoPaywall(
        context,
        eventId: widget.eventId,
        sessionId: widget.sessionId,
      );
      if (!ok || !mounted) return;
    }
    final session = _session;
    final line = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(
        builder: (_) => EchoSummaryScreen(
          eventId: widget.eventId,
          sessionId: widget.sessionId,
          session: session,
          language: _language,
          lineAt: _lineAt,
        ),
      ),
    );
    if (line != null && mounted) _jumpToLine(line);
  }

  /// Index of the loaded line closest to [atSeconds], or null when none is
  /// within [_jumpTolerance] (not revealed yet, or no transcript).
  int? _lineAt(int atSeconds) {
    int? best;
    var bestDiff = _jumpTolerance + 1;
    for (final e in _entries) {
      if (e is! _Line) continue;
      final diff = (e.line.atSeconds - atSeconds).abs();
      if (diff < bestDiff) {
        best = e.index;
        bestDiff = diff;
      }
    }
    return best;
  }

  /// Scrolls the transcript to line [index] and highlights it (the same
  /// highlight as tapping it, with "Ask about this").
  void _jumpToLine(int index) {
    final pos = _entries.indexWhere((e) => e is _Line && e.index == index);
    if (pos < 0) return;
    setState(() {
      _selected = index;
      _atBottom = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scroll.hasClients) return;
      _autoScrolls++;
      try {
        // Rows have different heights and only visible ones are built:
        // jump to an estimate until the row exists, then fine-tune.
        for (var i = 0; i < 3 && _selectedKey.currentContext == null; i++) {
          final max = _scroll.position.maxScrollExtent;
          final total = math.max(1, _entries.length - 1);
          _scroll.jumpTo((max * pos / total).clamp(0.0, max));
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
        }
        final row = _selectedKey.currentContext;
        if (row != null && row.mounted) {
          await Scrollable.ensureVisible(
            row,
            alignment: 0.3,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } finally {
        _autoScrolls--;
      }
      if (mounted && _scroll.hasClients) {
        setState(() => _atBottom = _scroll.position.extentAfter < 48);
      }
    });
  }

  Session? get _session =>
      (ref.read(agendaProvider(widget.eventId)).value ?? const <Session>[])
          .where((s) => s.id == widget.sessionId)
          .firstOrNull;

  void _showQuestions() {
    _loadQuestions(); // pick up others' questions and votes
    final name = _session?.speakers.firstOrNull?.name.split(' ').first;
    showEchoQuestions(
      context,
      questions: _questions,
      speakerName: name,
      onVote: _vote,
      onAsk: _submitQuestion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(agendaProvider(widget.eventId)).value ?? [];
    final session = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final unlocked = ref
        .watch(unlockedSummariesProvider)
        .contains(widget.sessionId);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              session: session,
              live: _lineCount > 0 && !_ended,
              ended: _ended,
              translate: _translate,
              onTranslate: _toggleTranslate,
            ),
            if (_translate) _TranslatedBanner(ended: _ended),
            if (_ended)
              _SummaryCard(unlocked: unlocked, onTap: _openSummary)
            else
              _CatchUpCard(
                catchUp: _catchUp,
                error: _catchUpLoading || _catchUpError == null
                    ? null
                    : _errorText(l10n, _catchUpError!),
                onLoad: _loadCatchUp,
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
                            key: _selected == index ? _selectedKey : null,
                            line: line,
                            translated: _translate
                                ? _translations[index] ??
                                      (line.translated.isNotEmpty
                                          ? line.translated
                                          : null)
                                : null,
                            // The newest lines are in full ink, older ones
                            // fade to secondary (design).
                            recent: index >= _lineCount - 3,
                            live: !_ended && index == _lineCount - 1,
                            selected: _selected == index,
                            onSelect: () => setState(
                              () =>
                                  _selected = _selected == index ? null : index,
                            ),
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  if (!_atBottom)
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.eho.ink,
                          foregroundColor: context.eho.onInk,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: Theme.of(context).textTheme.labelLarge,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        label: Text(
                          _ended ? l10n.echoJumpToEnd : l10n.echoJumpToLive,
                        ),
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
              onOpenQuestions: _showQuestions,
            ),
          ],
        ),
      ),
    );
  }
}

/// Back button, "LIVE · stage" + title, and the EN/SR translate pill.
class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.live,
    required this.ended,
    required this.translate,
    required this.onTranslate,
  });

  final Session? session;
  final bool live;
  final bool ended;
  final bool translate;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final stage = session?.stage ?? '';
    final muted = t.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final Widget? overline = stage.isEmpty
        ? null
        : live
        ? LiveBadge(l10n.echoLiveAt(stage))
        : Text(
            (ended ? l10n.echoEndedAt(stage) : stage).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surfaceContainer,
                  foregroundColor: scheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?overline,
                  const SizedBox(height: 2),
                  Text(
                    session?.title ?? l10n.echoTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: translate ? l10n.echoShowOriginal : l10n.echoTranslate,
              child: Material(
                color: translate ? scheme.primary : scheme.surface,
                shape: StadiumBorder(
                  side: translate
                      ? BorderSide.none
                      : BorderSide(color: scheme.outline),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTranslate,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.translate,
                          size: 18,
                          color: translate
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          translate
                              ? l10n.echoLangTranslated
                              : l10n.echoLangOriginal,
                          style: t.labelLarge?.copyWith(
                            color: translate
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslatedBanner extends StatelessWidget {
  const _TranslatedBanner({required this.ended});

  /// An ended talk was not translated "live".
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eho = context.eho;
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.translate, size: 16, color: eho.primaryPressed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ended
                  ? AppLocalizations.of(context).echoTranslatedBannerEnded
                  : AppLocalizations.of(context).echoTranslatedBanner,
              style: theme.textTheme.labelMedium?.copyWith(
                color: eho.primaryPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blue "Catch up" card; expanding it (re)loads the summary so far.
class _CatchUpCard extends StatefulWidget {
  const _CatchUpCard({
    required this.catchUp,
    required this.error,
    required this.onLoad,
  });

  final String? catchUp;
  final String? error;
  final VoidCallback onLoad;

  @override
  State<_CatchUpCard> createState() => _CatchUpCardState();
}

class _CatchUpCardState extends State<_CatchUpCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final body = t.bodySmall?.copyWith(color: eho.bodyOnTint, height: 1.45);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: EhoCard(
        color: theme.colorScheme.primaryContainer,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () {
          setState(() => _open = !_open);
          if (_open) widget.onLoad();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, size: 18, color: eho.primaryPressed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.echoCatchUp,
                    style: t.labelLarge?.copyWith(color: eho.primaryPressed),
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: eho.primaryPressed,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!_open)
              Text(
                widget.catchUp ?? l10n.echoCatchUpSubtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: body,
              )
            else if (widget.error != null) ...[
              Text(widget.error!, style: body),
              TextButton(onPressed: widget.onLoad, child: Text(l10n.echoRetry)),
            ] else
              Text(widget.catchUp ?? l10n.echoSummarizing, style: body),
          ],
        ),
      ),
    );
  }
}

/// After the talk: entry to the premium full summary.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.unlocked, required this.onTap});

  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: EhoCard(
        color: scheme.surfaceContainer,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.auto_awesome : Icons.lock_outline,
              size: 20,
              color: scheme.onSurface,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.echoFullSummary, style: t.titleSmall),
                  Text(
                    unlocked ? l10n.echoUnlocked : l10n.echoPremiumSubtitle,
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _TranscriptRow extends StatelessWidget {
  const _TranscriptRow({
    super.key,
    required this.line,
    required this.translated,
    required this.recent,
    required this.live,
    required this.selected,
    required this.onSelect,
    required this.onAsk,
  });

  final TranscriptLine line;

  /// Shown instead of the original when set (translate on and translated).
  final String? translated;
  final bool recent;

  /// The line being spoken now: ends with the live cursor.
  final bool live;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final m = (line.atSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (line.atSeconds % 60).toString().padLeft(2, '0');
    final style = t.bodyLarge?.copyWith(
      color: recent || selected ? scheme.onSurface : scheme.onSurfaceVariant,
    );
    final text = translated ?? line.text;
    return InkWell(
      onTap: onSelect,
      onLongPress: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '$m:$s',
                  style: t.labelMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: selected
                        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                        : EdgeInsets.zero,
                    decoration: selected
                        ? BoxDecoration(
                            color: eho.liveContainer,
                            borderRadius: BorderRadius.circular(8),
                          )
                        : null,
                    child: live
                        ? Text.rich(
                            TextSpan(
                              text: text,
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Container(
                                    width: 2,
                                    height: 18,
                                    margin: const EdgeInsets.only(left: 4),
                                    color: eho.live,
                                  ),
                                ),
                              ],
                            ),
                            style: style,
                          )
                        : Text(text, style: style),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: eho.ink,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onAsk,
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: eho.onInk,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(context).echoAskAboutThis,
                                style: t.labelMedium?.copyWith(
                                  color: eho.onInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
    final theme = Theme.of(context);
    final t = theme.textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiHint(question),
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
              style: t.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else
            Text(answer!, style: t.bodyMedium),
        ],
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}

/// Ask AI / Ask speaker track (selected segment white with primary text).
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onMode});

  final _Mode mode;
  final ValueChanged<_Mode> onMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    Widget segment(_Mode m, String label) {
      final on = mode == m;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: Material(
            color: on ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onMode(m),
              child: SizedBox(
                height: 38,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: on ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          segment(_Mode.ai, l10n.echoAskAi),
          const SizedBox(width: 4),
          segment(_Mode.speaker, l10n.echoAskSpeaker),
        ],
      ),
    );
  }
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
    final scheme = Theme.of(context).colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final speaker = mode == _Mode.speaker;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ModeToggle(mode: mode, onMode: onMode),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: l10n.echoQuestionsTitle,
                    onPressed: onOpenQuestions,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainer,
                      foregroundColor: scheme.onSurface,
                      fixedSize: const Size(46, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Badge.count(
                      count: questionCount,
                      isLabelVisible: questionCount > 0,
                      backgroundColor: eho.live,
                      textColor: eho.onLive,
                      child: const Icon(Icons.forum_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: speaker ? l10n.echoSpeakerHint : l10n.echoAskHint,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(6),
                    child: IconButton(
                      tooltip: l10n.echoSend,
                      onPressed: () => onSend(),
                      style: IconButton.styleFrom(
                        backgroundColor: speaker ? eho.live : scheme.primary,
                        foregroundColor: speaker
                            ? eho.onLive
                            : scheme.onPrimary,
                        minimumSize: const Size(40, 40),
                        fixedSize: const Size(40, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    ),
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
