import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_state.dart';
import '../../l10n/app_localizations.dart';

/// Profile tab: who you are, consent switches, My events.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabProfile)),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              child: Text(p.name.isEmpty ? '?' : p.name[0]),
            ),
            title: Text(
              p.name.isEmpty ? l10n.profileYourName : p.name,
              style: t.titleLarge,
            ),
            subtitle: Text(p.headline),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => context.push('/onboarding'),
          ),
          if (p.interests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [for (final i in p.interests) Chip(label: Text(i))],
              ),
            ),
          if (p.lookingFor.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.search),
              title: Text(l10n.lookingFor),
              subtitle: Text(p.lookingFor),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.profilePrivacy),
          ),
          SwitchListTile(
            title: Text(l10n.showMeInFind),
            value: p.visibleInFind,
            onChanged: (v) => notifier.save(p.copyWith(visibleInFind: v)),
          ),
          SwitchListTile(
            title: Text(l10n.allowContactRequests),
            value: p.allowContact,
            onChanged: (v) => notifier.save(p.copyWith(allowContact: v)),
          ),
          SwitchListTile(
            title: Text(l10n.allowMeetingSpots),
            value: p.shareMeetingSpot,
            onChanged: (v) => notifier.save(p.copyWith(shareMeetingSpot: v)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.event_note),
            title: Text(l10n.myEvents),
            subtitle: Text(
              l10n.profileJoinedCount(ref.watch(joinedEventsProvider).length),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/events'),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(l10n.profileTalkSummaries),
            subtitle: Text(
              l10n.profileUnlockedCount(
                ref.watch(unlockedSummariesProvider).length,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.profileForOrganizers),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(l10n.profileCreateEvent),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/organizer'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_location_alt_outlined),
            title: Text(l10n.profileEditVenueMap),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/o'),
          ),
        ],
      ),
    );
  }
}
