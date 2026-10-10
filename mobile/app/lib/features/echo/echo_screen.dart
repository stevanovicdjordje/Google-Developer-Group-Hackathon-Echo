import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
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
  _Line(this.line);
  final TranscriptLine line;
}

class _Answer extends _Entry {
  _Answer(this.question);
  final String question;
  String? answer;
}

class _EchoScreenState extends ConsumerState<EchoScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  final _entries = <_Entry>[];
  final _answers = <_Answer>[];
  List<SpeakerQuestion> _questions = [];
  String? _catchUp;
  bool _translate = false;
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
    _repo.transcript(widget.eventId, widget.sessionId).listen(
      (lines) {
        if (!mounted) return;
        setState(() {
          for (final l in lines.skip(_lineCount)) {
            _entries.add(_Line(l));
          }
          _lineCount = lines.length;
        });
        _toBottom();
      },
      onDone: () {
        if (mounted) setState(() => _ended = true);
      },
    );
    _repo.catchUp(widget.eventId, widget.sessionId).then((s) {
      if (mounted) setState(() => _catchUp = s);
    });
    _repo.questions(widget.eventId, widget.sessionId).then((q) {
      if (mounted) setState(() => _questions = q);
    });
  }

  @override
  void dispose() {
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
    _input.text = 'What did the speaker mean by: "${line.text}"';
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
      final q = await _repo.submitQuestion(
        widget.eventId,
        widget.sessionId,
        text,
      );
      if (!mounted) return;
      setState(() => _questions = [q, ..._questions]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question sent to the speaker')),
      );
      return;
    }
    final a = _Answer(text);
    setState(() {
      _entries.add(a);
      _answers.add(a);
    });
    _toBottom(force: true);
    final answer = await _repo.ask(widget.eventId, widget.sessionId, text);
    if (!mounted) return;
    setState(() => a.answer = answer);
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(agendaProvider(widget.eventId)).value ?? [];
    final session = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          session?.title ?? 'Echo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _translate ? 'Show original' : 'Translate to Serbian',
            icon: Icon(
              Icons.translate,
              color: _translate ? scheme.primary : null,
            ),
            onPressed: () => setState(() => _translate = !_translate),
          ),
        ],
      ),
      body: Column(
        children: [
          _SummaryStrip(
            sessionId: widget.sessionId,
            eventId: widget.eventId,
            catchUp: _catchUp,
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
                        _Line(:final line) => _TranscriptRow(
                          line: line,
                          translate: _translate,
                          onAsk: () => _askAbout(line),
                        ),
                        final _Answer a => _AnswerCard(a.question, a.answer),
                      };
                    },
                  ),
                ),
                if (!_atBottom)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: const Text('Jump to live'),
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
            questionCount: _questions.length,
            onMode: (m) => setState(() => _mode = m),
            onSend: _send,
            onOpenQuestions: () => _showQuestions(context),
          ),
        ],
      ),
    );
  }

  void _showQuestions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final sorted = [..._questions]
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
                    'Questions for the speaker',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final q in sorted)
                  ListTile(
                    title: Text(q.text),
                    subtitle: q.mine ? const Text('Your question') : null,
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.arrow_upward),
                      label: Text('${q.votes}'),
                      onPressed: () {
                        setSheet(() => q.votes++);
                        setState(() {});
                      },
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
    required this.ended,
  });

  final String eventId;
  final String sessionId;
  final String? catchUp;
  final bool ended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (ended) {
      final unlocked = ref.watch(unlockedSummariesProvider).contains(sessionId);
      return Material(
        color: scheme.tertiaryContainer,
        child: ListTile(
          leading: Icon(unlocked ? Icons.summarize : Icons.lock_outline),
          title: const Text('Full talk summary'),
          subtitle: Text(unlocked ? 'Unlocked' : 'Premium · AI summary of the whole talk'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openSummary(context, ref, unlocked),
        ),
      );
    }
    return Material(
      color: scheme.surfaceContainerHigh,
      child: ExpansionTile(
        leading: const Icon(Icons.bolt),
        title: const Text('Catch up'),
        subtitle: const Text('What was said so far'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Text(catchUp ?? 'Summarizing…')],
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
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.workspace_premium),
          title: const Text('Unlock talk summaries'),
          content: const Text(
            'Get an AI summary of every talk at this event: key points, '
            'trade-offs and takeaways.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Unlock · €2.99'),
            ),
          ],
        ),
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
        builder: (context, scroll) => FutureBuilder<String>(
          future: ref.read(echoRepositoryProvider).fullSummary(eventId, sessionId),
          builder: (context, snap) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(24),
            children: [
              if (!snap.hasData)
                const Center(child: CircularProgressIndicator())
              else
                Text(snap.data!, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranscriptRow extends StatelessWidget {
  const _TranscriptRow({
    required this.line,
    required this.translate,
    required this.onAsk,
  });

  final TranscriptLine line;
  final bool translate;
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
          items: const [
            PopupMenuItem(
              value: true,
              child: ListTile(
                leading: Icon(Icons.auto_awesome),
                title: Text('Ask about this'),
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
            Expanded(
              child: Text(
                translate ? line.translated : line.text,
                style: t.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard(this.question, this.answer);

  final String question;
  final String? answer;

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
            answer == null
                ? const LinearProgressIndicator()
                : Text(answer!, style: t.bodyMedium),
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
            'Talk ended',
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
  Widget build(BuildContext context) => Material(
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
                    segments: const [
                      ButtonSegment(value: _Mode.ai, label: Text('Ask AI')),
                      ButtonSegment(
                        value: _Mode.speaker,
                        label: Text('Ask speaker'),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => onMode(s.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Questions for the speaker',
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
                    ? 'Ask about this talk…'
                    : 'Question for the speaker…',
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
