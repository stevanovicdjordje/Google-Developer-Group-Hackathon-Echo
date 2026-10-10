import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui/ui.dart';
import '../../data/echo_models.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';

enum _Sort { top, newest, mine }

/// Opens the "Questions for (speaker)" sheet: sort chips, vote buttons and
/// an ask-the-speaker input. [questions] is the screen's live list (newest
/// first); [onAsk] returns the submission once sent (null on failure).
Future<void> showEchoQuestions(
  BuildContext context, {
  required ValueListenable<List<SpeakerQuestion>> questions,
  required String? speakerName,
  required ValueChanged<SpeakerQuestion> onVote,
  required Future<QuestionSubmission?> Function(String text) onAsk,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => EchoQaSheet(
    questions: questions,
    speakerName: speakerName,
    onVote: onVote,
    onAsk: onAsk,
  ),
);

class EchoQaSheet extends StatefulWidget {
  const EchoQaSheet({
    super.key,
    required this.questions,
    required this.speakerName,
    required this.onVote,
    required this.onAsk,
  });

  final ValueListenable<List<SpeakerQuestion>> questions;
  final String? speakerName;
  final ValueChanged<SpeakerQuestion> onVote;
  final Future<QuestionSubmission?> Function(String text) onAsk;

  @override
  State<EchoQaSheet> createState() => _EchoQaSheetState();
}

class _EchoQaSheetState extends State<EchoQaSheet> {
  final _input = TextEditingController();
  _Sort _sort = _Sort.top;
  bool _sending = false;

  /// The last question you sent was merged into a similar one.
  bool _merged = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Client-side order. There is no timestamp on a question, so "Newest" is
  /// the list order (the screen prepends questions you ask).
  List<SpeakerQuestion> _sorted(List<SpeakerQuestion> all) => switch (_sort) {
    _Sort.top => [...all]..sort((a, b) => b.votes.compareTo(a.votes)),
    _Sort.newest => all,
    _Sort.mine => [
      for (final q in all)
        if (q.mine) q,
    ],
  };

  Future<void> _ask() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await widget.onAsk(text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (sent != null) {
        _input.clear();
        _sort = _Sort.newest; // show it at the top
        _merged = sent.merged;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final inset = mq.viewInsets.bottom;
    final height = math.min(
      mq.size.height * 0.82,
      mq.size.height - inset - mq.padding.top - 24,
    );
    final name = widget.speakerName;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: ValueListenableBuilder<List<SpeakerQuestion>>(
          valueListenable: widget.questions,
          builder: (context, all, _) {
            final shown = _sorted(all);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name == null
                                  ? l10n.echoQuestionsTitle
                                  : l10n.echoQuestionsFor(name),
                              style: t.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.echoQuestionsMeta(all.length),
                              style: t.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.surfaceContainer,
                          foregroundColor: scheme.onSurface,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (s, label) in [
                        (_Sort.top, l10n.echoSortTop),
                        (_Sort.newest, l10n.echoSortNewest),
                        (_Sort.mine, l10n.echoSortMine),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _sort == s,
                          onSelected: (_) => setState(() => _sort = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: shown.isEmpty
                        ? Center(
                            child: Text(
                              _sort == _Sort.mine
                                  ? l10n.echoNoMyQuestions
                                  : l10n.echoNoQuestions,
                              textAlign: TextAlign.center,
                              style: t.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: shown.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => _QuestionCard(
                              shown[i],
                              onVote: () => widget.onVote(shown[i]),
                            ),
                          ),
                  ),
                  if (_merged) ...[
                    const SizedBox(height: 10),
                    AiHint(
                      l10n.echoQuestionMerged,
                      style: t.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(
                      hintText: name == null
                          ? l10n.echoSpeakerHint
                          : l10n.echoAskNameHint(name),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(6),
                        child: IconButton(
                          tooltip: l10n.echoSendQuestion,
                          onPressed: _sending ? null : _ask,
                          style: IconButton.styleFrom(
                            backgroundColor: eho.live,
                            foregroundColor: eho.onLive,
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
            );
          },
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard(this.q, {required this.onVote});

  final SpeakerQuestion q;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final question = Text(q.text, style: t.bodyLarge?.copyWith(height: 1.4));
    // "3 similar questions merged" (design: AI chip under the text).
    final text = q.mergedCount <= 0
        ? question
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              question,
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 12,
                      color: eho.primaryPressed,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.echoMergedCount(q.mergedCount),
                        style: t.labelSmall?.copyWith(
                          color: eho.primaryPressed,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: q.mine ? scheme.surface : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: q.mine ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: q.mine
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.echoYourQuestion.toUpperCase(),
                        style: t.labelSmall?.copyWith(color: scheme.primary),
                      ),
                      const SizedBox(height: 6),
                      text,
                    ],
                  )
                : text,
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            toggled: q.voted,
            label: l10n.echoUpvote,
            child: Material(
              color: q.voted ? scheme.primary : scheme.surface,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onVote,
                child: SizedBox(
                  width: 52,
                  height: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        size: 20,
                        color: q.voted ? scheme.onPrimary : scheme.onSurface,
                      ),
                      Text(
                        '${q.votes}',
                        style: t.titleSmall?.copyWith(
                          color: q.voted ? scheme.onPrimary : scheme.onSurface,
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
    );
  }
}
