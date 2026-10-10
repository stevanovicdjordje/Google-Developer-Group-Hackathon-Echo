import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
import 'echo_errors.dart';

/// One row of the "Trade-offs and fixes" table.
typedef SummaryTradeoff = ({String issue, String detail});

/// The full summary split into the parts the design shows.
class ParsedSummary {
  const ParsedSummary({
    required this.takeaway,
    required this.keyPoints,
    required this.tradeoffs,
    required this.paragraphs,
  });

  final String? takeaway;
  final List<String> keyPoints;
  final List<SummaryTradeoff> tradeoffs;

  /// Plain paragraphs that are neither the takeaway nor a heading.
  final List<String> paragraphs;
}

final _bullet = RegExp(r'^\s*[•\-\*–]\s+');
final _takeawayLabel = RegExp(
  r'^(takeaway|advice|bottom line|conclusion)\s*:\s*',
  caseSensitive: false,
);

/// Splits the plain-text summary (`•` bullet lines, optional section
/// headings like "Key points" / "Trade-offs and fixes" / "Takeaway").
///
/// TODO(mobile#9): use the structured fields (`takeaway`, `keyPoints[]`,
/// `tradeoffs[]` with `atSeconds`) once feature:echo returns them.
ParsedSummary parseEchoSummary(String text, {String? title}) {
  final lines = [
    for (final l in text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  bool isBullet(String l) => _bullet.hasMatch(l);
  String strip(String l) => l.replaceFirst(_bullet, '').trim();

  String? takeaway;
  final keyPoints = <String>[];
  final tradeoffs = <SummaryTradeoff>[];
  final paragraphs = <String>[];
  String section = '';

  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (!isBullet(l)) {
      final next = i + 1 < lines.length ? lines[i + 1] : null;
      final heading =
          next != null &&
          l.length <= 40 &&
          !l.endsWith('.') &&
          !l.endsWith(':');
      if (heading) {
        section = l.toLowerCase();
        continue;
      }
      if (title != null && title.isNotEmpty && l.startsWith(title)) continue;
      if (section.contains('takeaway')) {
        takeaway = takeaway == null ? l : '$takeaway $l';
      } else {
        paragraphs.add(l);
      }
      continue;
    }
    final item = strip(l);
    if (section.contains('trade-off') || section.contains('tradeoff')) {
      final colon = item.indexOf(':');
      if (colon > 0 && colon < 40) {
        tradeoffs.add((
          issue: item.substring(0, colon).trim(),
          detail: item.substring(colon + 1).trim(),
        ));
      } else {
        tradeoffs.add((issue: item, detail: ''));
      }
    } else if (section.contains('takeaway')) {
      takeaway = takeaway == null ? item : '$takeaway $item';
    } else {
      keyPoints.add(item);
    }
  }

  if (takeaway == null && paragraphs.isNotEmpty) {
    takeaway = paragraphs.removeAt(0);
  }
  if (takeaway == null) {
    final labeled = keyPoints.indexWhere(_takeawayLabel.hasMatch);
    if (labeled >= 0) {
      takeaway = keyPoints.removeAt(labeled).replaceFirst(_takeawayLabel, '');
    } else if (keyPoints.isNotEmpty) {
      takeaway = keyPoints.removeAt(0);
    }
  }
  return ParsedSummary(
    takeaway: takeaway,
    keyPoints: keyPoints,
    tradeoffs: tradeoffs,
    paragraphs: paragraphs,
  );
}

/// Minutes between "HH:mm" [start] and [end], or null.
int? _minutes(String start, String end) {
  int? parse(String s) {
    final p = s.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    return h == null || m == null ? null : h * 60 + m;
  }

  final a = parse(start), b = parse(end);
  return a == null || b == null || b <= a ? null : b - a;
}

/// Premium talk summary (after unlock): takeaway, key points, trade-offs.
class EchoSummaryScreen extends ConsumerStatefulWidget {
  const EchoSummaryScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
    this.session,
  });

  final String eventId;
  final String sessionId;
  final Session? session;

  @override
  ConsumerState<EchoSummaryScreen> createState() => _EchoSummaryScreenState();
}

class _EchoSummaryScreenState extends ConsumerState<EchoSummaryScreen> {
  late Future<String> _summary = _load();

  Future<String> _load() => ref
      .read(echoRepositoryProvider)
      .fullSummary(widget.eventId, widget.sessionId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _summary,
          builder: (context, snap) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _RoundButton(
                      icon: Icons.chevron_left,
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                    // The summary API has no language parameter, so the
                    // design's translate button is left out for now.
                    if (snap.hasData)
                      _RoundButton(
                        icon: Icons.copy_rounded,
                        tooltip: l10n.echoCopySummary,
                        onPressed: () => _copy(snap.data!),
                      ),
                  ],
                ),
              ),
              Expanded(child: _body(context, snap)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = AppLocalizations.of(context).echoSummaryCopied;
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  Widget _body(BuildContext context, AsyncSnapshot<String> snap) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    if (snap.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                echoErrorText(l10n, snap.error!),
                textAlign: TextAlign.center,
                style: t.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _summary = _load()),
                child: Text(l10n.echoRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (!snap.hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.echoThinking, style: t.bodyMedium),
          ],
        ),
      );
    }
    final s = widget.session;
    final text = snap.data!;
    final parsed = parseEchoSummary(text, title: s?.title);
    final talkMinutes = s == null ? null : _minutes(s.start, s.end);
    final words = text.split(RegExp(r'\s+')).length;
    final meta = [
      if (s != null && s.speakers.isNotEmpty)
        s.speakers.map((p) => p.name).join(', '),
      if (talkMinutes != null) l10n.echoTalkMinutes(talkMinutes),
      l10n.echoReadMinutes((words / 200).ceil().clamp(1, 99)),
    ].join(' · ');
    final bullet = t.bodyMedium?.copyWith(height: 1.5);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: eho.liveContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: eho.onLiveContainer),
                const SizedBox(width: 6),
                Text(
                  l10n.echoSummaryBadge.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: eho.onLiveContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (s != null) Text(s.title, style: t.headlineMedium),
        const SizedBox(height: 8),
        Text(
          meta,
          style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (parsed.takeaway != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: eho.ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.echoTakeaway.toUpperCase(),
                  style: t.labelSmall?.copyWith(
                    color: eho.onInkPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  parsed.takeaway!,
                  style: t.bodyLarge?.copyWith(
                    color: eho.onInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (parsed.keyPoints.isNotEmpty || parsed.paragraphs.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(l10n.echoKeyPoints, style: t.titleMedium),
          for (final p in parsed.paragraphs)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(p, style: bullet),
            ),
          for (final p in parsed.keyPoints)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 9, right: 10),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: _LabeledText(p, style: bullet)),
                ],
              ),
            ),
        ],
        // TODO(mobile#9): end each row with the timestamp link back into the
        // transcript once the API returns `tradeoffs[].atSeconds`.
        if (parsed.tradeoffs.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(l10n.echoTradeoffs, style: t.titleMedium),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final (i, row) in parsed.tradeoffs.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.issue, style: t.titleSmall),
                        if (row.detail.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            row.detail,
                            style: t.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "Label: text" with the label in semibold (API bullets look like that).
class _LabeledText extends StatelessWidget {
  const _LabeledText(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colon = text.indexOf(':');
    if (colon <= 0 || colon > 32) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: text.substring(0, colon + 1),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text.substring(colon + 1)),
        ],
      ),
    );
  }
}

/// 44×44 round button on the background tint (design's header buttons).
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
    ),
    icon: Icon(icon),
  );
}
