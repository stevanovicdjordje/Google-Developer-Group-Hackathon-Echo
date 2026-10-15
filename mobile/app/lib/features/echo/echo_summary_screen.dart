import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/echo_models.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
import 'echo_errors.dart';

/// One row of the "Trade-offs and fixes" table; [atSeconds] links back to
/// the transcript when known.
typedef SummaryTradeoff = ({String issue, String detail, int? atSeconds});

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

  /// The structured summary (Echo 0.3.0): each trade-off row reads
  /// "issue → fix" (design) and keeps its transcript time.
  factory ParsedSummary.fromTalkSummary(TalkSummary s) => ParsedSummary(
    takeaway: s.takeaway,
    keyPoints: s.keyPoints,
    tradeoffs: [
      for (final t in s.tradeoffs)
        (
          issue: t.topic,
          detail: [t.issue, t.fix].where((x) => x.isNotEmpty).join(' → '),
          atSeconds: t.atSeconds,
        ),
    ],
    paragraphs: const [],
  );
}

final _bullet = RegExp(r'^\s*[•\-\*–]\s+');
final _takeawayLabel = RegExp(
  r'^(takeaway|advice|bottom line|conclusion)\s*:\s*',
  caseSensitive: false,
);

/// Splits the plain-text summary (`•` bullet lines, optional section
/// headings like "Key points" / "Trade-offs and fixes" / "Takeaway").
/// Fallback for when the response has no structured `summary` (servers
/// before Echo 0.3.0, or a summary that didn't parse).
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
          atSeconds: null,
        ));
      } else {
        tradeoffs.add((issue: item, detail: '', atSeconds: null));
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

/// "mm:ss" like the transcript's time column.
String _clock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
    '${(seconds % 60).toString().padLeft(2, '0')}';

/// Premium talk summary (after unlock): takeaway, key points, trade-offs.
class EchoSummaryScreen extends ConsumerStatefulWidget {
  const EchoSummaryScreen({
    super.key,
    required this.eventId,
    required this.sessionId,
    this.session,
    this.language = 'en',
    this.lineAt,
  });

  final String eventId;
  final String sessionId;
  final Session? session;

  /// Language the summary is first requested in (`sr` when Echo's translate
  /// is on); the header's translate button switches between it and English.
  final String language;

  /// Index of the loaded transcript line at [atSeconds], or null when that
  /// line isn't there. A trade-off time with a line is a link that pops this
  /// page with the line index (the Echo screen then scrolls to it); without
  /// one it shows the time only.
  final int? Function(int atSeconds)? lineAt;

  @override
  ConsumerState<EchoSummaryScreen> createState() => _EchoSummaryScreenState();
}

class _EchoSummaryScreenState extends ConsumerState<EchoSummaryScreen> {
  late String _language = widget.language;
  late Future<EchoSummary> _summary = _load();

  Future<EchoSummary> _load() => ref
      .read(echoRepositoryProvider)
      .fullSummary(widget.eventId, widget.sessionId, language: _language);

  /// Serbian <-> English (Serbian is the app's translate target, as on Echo).
  void _toggleLanguage() => setState(() {
    _language = _language == 'sr' ? 'en' : 'sr';
    _summary = _load();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: FutureBuilder<EchoSummary>(
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
                    _RoundButton(
                      icon: Icons.translate,
                      tooltip: _language == 'sr'
                          ? l10n.echoShowOriginal
                          : l10n.echoTranslate,
                      selected: _language == 'sr',
                      onPressed: _toggleLanguage,
                    ),
                    if (snap.hasData) ...[
                      const SizedBox(width: 8),
                      _RoundButton(
                        icon: Icons.ios_share,
                        tooltip: l10n.echoCopySummary,
                        onPressed: () => _copy(snap.data!.text),
                      ),
                    ],
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

  Widget _body(BuildContext context, AsyncSnapshot<EchoSummary> snap) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    if (snap.hasError && snap.connectionState == ConnectionState.done) {
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
    if (!snap.hasData || snap.connectionState != ConnectionState.done) {
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
    final text = snap.data!.text;
    final structured = snap.data!.summary;
    final parsed = structured != null
        ? ParsedSummary.fromTalkSummary(structured)
        : parseEchoSummary(text, title: s?.title);
    final talkMinutes = s == null ? null : _minutes(s.start, s.end);
    // ~200 words per minute over what the page shows, at least 1 minute.
    final words = [
      ?s?.title,
      ?parsed.takeaway,
      ...parsed.keyPoints,
      ...parsed.paragraphs,
      for (final r in parsed.tradeoffs) ...[r.issue, r.detail],
    ].join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
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
                        if (row.detail.isNotEmpty || row.atSeconds != null) ...[
                          const SizedBox(height: 3),
                          _TradeoffDetail(
                            row.detail,
                            atSeconds: row.atSeconds,
                            line: row.atSeconds == null
                                ? null
                                : widget.lineAt?.call(row.atSeconds!),
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

/// Trade-off detail ending with its transcript time: a link back to the
/// transcript when [line] is known, plain text otherwise.
class _TradeoffDetail extends StatelessWidget {
  const _TradeoffDetail(this.detail, {this.atSeconds, this.line});

  final String detail;
  final int? atSeconds;
  final int? line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.45,
    );
    final at = atSeconds;
    if (at == null) return Text(detail, style: style);
    final time = _clock(at);
    final prefix = detail.isEmpty
        ? ''
        : detail.endsWith('.')
        ? '$detail '
        : '$detail. ';
    final l = line;
    if (l == null) return Text('$prefix$time', style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: prefix),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Semantics(
              link: true,
              label: AppLocalizations.of(context).echoJumpToTime(time),
              excludeSemantics: true,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(l),
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  time,
                  style: style?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: scheme.primary,
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
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Filled primary (the translate button while Serbian is shown).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected ? scheme.primary : scheme.surfaceContainer,
        foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
      ),
      icon: Icon(icon),
    );
  }
}
