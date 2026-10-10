/// Echo types added with `contracts/echo` 0.3.0 (`mobile#9`): the structured
/// talk summary and the result of submitting a question.
library;

import 'models.dart';

/// One "problem → fix" row of the summary; [atSeconds] is the start time of
/// the transcript line where the problem is stated (null when unknown).
class EchoTradeoff {
  const EchoTradeoff({
    required this.topic,
    required this.issue,
    required this.fix,
    this.atSeconds,
  });

  final String topic;
  final String issue;
  final String fix;
  final int? atSeconds;
}

/// `TalkSummary`: takeaway, key points and trade-offs.
class TalkSummary {
  const TalkSummary({
    required this.takeaway,
    required this.keyPoints,
    required this.tradeoffs,
  });

  final String takeaway;
  final List<String> keyPoints;
  final List<EchoTradeoff> tradeoffs;

  static const _maxTopic = 40;
  static const _maxText = 300;
  static const _maxItems = 5;

  /// Parses untrusted model output (`AGENTS.md` rule 12): wrong types and
  /// empty strings are dropped, lengths and list sizes capped. Null when
  /// nothing usable is left (no takeaway and no key points), so the caller
  /// falls back to the plain `text`.
  static TalkSummary? tryParse(Object? json) {
    if (json is! Map) return null;
    String? str(Object? v, int max) {
      if (v is! String) return null;
      final s = v.trim();
      if (s.isEmpty) return null;
      return s.length > max ? '${s.substring(0, max)}…' : s;
    }

    final takeaway = str(json['takeaway'], _maxText);
    final rawPoints = json['keyPoints'];
    final keyPoints = <String>[
      if (rawPoints is List)
        for (final p in rawPoints)
          if (str(p, _maxText) case final String s) s,
    ].take(_maxItems).toList();
    final rawTradeoffs = json['tradeoffs'];
    final tradeoffs = <EchoTradeoff>[];
    if (rawTradeoffs is List) {
      for (final t in rawTradeoffs) {
        if (tradeoffs.length >= _maxItems) break;
        if (t is! Map) continue;
        final topic = str(t['topic'], _maxTopic);
        final issue = str(t['issue'], _maxText);
        final fix = str(t['fix'], _maxText);
        if (topic == null || (issue == null && fix == null)) continue;
        final at = t['atSeconds'];
        tradeoffs.add(
          EchoTradeoff(
            topic: topic,
            issue: issue ?? '',
            fix: fix ?? '',
            atSeconds: at is num && at >= 0 && at.isFinite ? at.toInt() : null,
          ),
        );
      }
    }
    if (takeaway == null && keyPoints.isEmpty) return null;
    return TalkSummary(
      takeaway: takeaway ?? keyPoints.removeAt(0),
      keyPoints: List.unmodifiable(keyPoints),
      tradeoffs: List.unmodifiable(tradeoffs),
    );
  }
}

/// `getSummary`: the plain [text] (always) and the structured [summary]
/// when the server sends one (since 0.3.0; demo data has one too).
class EchoSummary {
  const EchoSummary({required this.text, this.summary});

  final String text;
  final TalkSummary? summary;
}

/// `submitQuestion`: the question as it is now, and whether the server
/// merged it into a similar existing one ([question] is then that one).
class QuestionSubmission {
  const QuestionSubmission(this.question, {this.merged = false});

  final SpeakerQuestion question;
  final bool merged;
}
