import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/ui/ui.dart';
import '../../data/app_state.dart';
import '../../l10n/app_localizations.dart';

/// Profile tab: who you are, consent switches, My events.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final rowTitle = t.bodyLarge?.copyWith(fontSize: 16);
    final joined = ref.watch(joinedEventsProvider).length;

    Widget switchRow(String title, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(title, style: rowTitle),
          value: value,
          onChanged: onChanged,
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: Text(
                    p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                    style: t.headlineMedium?.copyWith(color: scheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name.isEmpty ? l10n.profileYourName : p.name,
                        style: t.headlineSmall,
                      ),
                      if (p.headline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          p.headline,
                          style: t.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: scheme.surface),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => context.push('/onboarding'),
                ),
              ],
            ),
            if (p.interests.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in p.interests)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outline),
                      ),
                      child: Text(i, style: t.bodySmall),
                    ),
                ],
              ),
            ],
            if (p.lookingFor.isNotEmpty) ...[
              const SizedBox(height: 16),
              EhoCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lookingFor,
                        style: t.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(p.lookingFor, style: t.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SectionLabel(l10n.profilePrivacy),
            ),
            _Group(
              children: [
                switchRow(
                  l10n.showMeInFind,
                  p.visibleInFind,
                  (v) => notifier.save(p.copyWith(visibleInFind: v)),
                ),
                switchRow(
                  l10n.allowContactRequests,
                  p.allowContact,
                  (v) => notifier.save(p.copyWith(allowContact: v)),
                ),
                switchRow(
                  l10n.allowMeetingSpots,
                  p.shareMeetingSpot,
                  (v) => notifier.save(p.copyWith(shareMeetingSpot: v)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Group(
              children: [
                _NavRow(
                  icon: Icons.calendar_today_outlined,
                  title: l10n.myEvents,
                  trailing: Text(
                    '$joined',
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => context.go('/events'),
                ),
                _NavRow(
                  icon: Icons.bookmark_border,
                  iconColor: eho.onLiveContainer,
                  title: l10n.profileTalkSummaries,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: eho.liveContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.profilePremium,
                      style: t.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: eho.onLiveContainer,
                      ),
                    ),
                  ),
                ),
                _NavRow(
                  icon: Icons.home_work_outlined,
                  title: l10n.profileForOrganizers,
                  chevron: true,
                  onTap: () => _showOrganizerSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chooser behind the "For organizers" row: create an event or edit a map.
void _showOrganizerSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showModalBottomSheet<void>(
    context: context,
    // Root navigator: the sheet and its scrim cover the event's bottom nav.
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.profileForOrganizers,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(l10n.profileCreateEvent),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(sheet);
              context.push('/organizer');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_location_alt_outlined),
            title: Text(l10n.profileEditVenueMap),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(sheet);
              context.push('/o');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// White radius-18 card holding rows separated by 1 px dividers.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.iconColor,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Color? iconColor;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? scheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
              ),
            ),
            ?trailing,
            if (chevron)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
