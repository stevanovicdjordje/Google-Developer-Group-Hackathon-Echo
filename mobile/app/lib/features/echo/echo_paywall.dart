import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/ui.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../agenda/agenda_screens.dart';
import '../join/join_screens.dart';

/// "Missed something?" paywall for the full talk summary (mocked payment).
/// Resolves to true when the user unlocked it.
Future<bool> showEchoPaywall(
  BuildContext context, {
  required String eventId,
  required String sessionId,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          EchoPaywallSheet(eventId: eventId, sessionId: sessionId),
    ) ??
    false;

enum _Plan { talk, event }

class EchoPaywallSheet extends ConsumerStatefulWidget {
  const EchoPaywallSheet({
    super.key,
    required this.eventId,
    required this.sessionId,
  });

  final String eventId;
  final String sessionId;

  @override
  ConsumerState<EchoPaywallSheet> createState() => _EchoPaywallSheetState();
}

class _EchoPaywallSheetState extends ConsumerState<EchoPaywallSheet> {
  _Plan _plan = _Plan.talk;

  List<Session> get _talks => [
    for (final s in ref.read(agendaProvider(widget.eventId)).value ?? [])
      if (!s.isBreak) s,
  ];

  /// The data layer unlocks one session at a time, so "every talk" unlocks
  /// each talk of the event's agenda.
  void _unlock() {
    final unlocked = ref.read(unlockedSummariesProvider.notifier);
    unlocked.unlock(widget.sessionId);
    if (_plan == _Plan.event) {
      for (final s in _talks) {
        unlocked.unlock(s.id);
      }
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(agendaProvider(widget.eventId)).value ?? [];
    final session = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    final event = ref.watch(eventSummaryProvider(widget.eventId)).value;
    final talks = sessions.where((s) => !s.isBreak).length;
    final talkSubtitle = [
      if (session != null) session.title,
      if (session != null && session.speakers.isNotEmpty)
        session.speakers.first.name,
    ].join(' · ');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: IconTile(Icons.lock_outline, live: true, size: 56),
            ),
            const SizedBox(height: 16),
            Text(l10n.echoPaywallTitle, style: t.headlineMedium),
            const SizedBox(height: 8),
            Text(
              l10n.echoPaywallBody,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _PlanOption(
              title: l10n.echoPaywallThisTalk,
              subtitle: talkSubtitle,
              price: l10n.echoPriceTalk,
              selected: _plan == _Plan.talk,
              onTap: () => setState(() => _plan = _Plan.talk),
            ),
            if (event != null && talks > 1) ...[
              const SizedBox(height: 10),
              _PlanOption(
                title: l10n.echoPaywallEveryTalk(event.name),
                subtitle: l10n.echoPaywallEveryTalkSubtitle(talks),
                price: l10n.echoPriceEvent,
                selected: _plan == _Plan.event,
                onTap: () => setState(() => _plan = _Plan.event),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _unlock,
              child: Text(l10n.echoUnlockSummary),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.echoNotNow),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radio card: title + subtitle on the left, price on the right.
class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: EhoCard(
        onTap: onTap,
        radius: 16,
        borderColor: selected ? scheme.primary : scheme.outline,
        borderWidth: selected ? 2 : 1.5,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: selected ? 6 : 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall?.copyWith(fontSize: 16)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(price, style: t.titleSmall?.copyWith(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
