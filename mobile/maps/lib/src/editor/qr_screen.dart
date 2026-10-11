import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/maps_localizations.dart';
import '../model/map_models.dart';
import 'editor_providers.dart';
import 'print_page.dart';
import 'qr_print.dart';

/// Origin of the links printed on QR signs. On web: the app's own origin, so
/// the codes open the deployment they were printed from.
final mapsLinkBaseProvider = Provider<String>((ref) {
  final base = Uri.base;
  if (base.scheme.startsWith('http')) return base.origin;
  return const String.fromEnvironment(
    'LINK_BASE',
    defaultValue: 'https://eho.app',
  );
});

/// Organizer page with the "you are here" QR signs of an event
/// (`/o/e/{eventId}/qr`): preview, links, and an A4 print sheet.
class MapQrScreen extends ConsumerWidget {
  const MapQrScreen({super.key, required this.eventId, this.openPage});

  final String eventId;

  /// Opens the print sheet; defaults to a new browser tab. For tests.
  final bool Function(String html)? openPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = MapsLocalizations.of(context);
    final state = ref.watch(editorProvider(eventId));
    final base = ref.watch(mapsLinkBaseProvider);

    final s = state.value;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.qrTitle)),
        body: Center(
          child: state.hasError
              ? Text(l10n.qrLoadFailed)
              : const CircularProgressIndicator(),
        ),
      );
    }

    final floors = {for (final f in s.draft.floors) f.id: f};
    final markers =
        s.draft.features.where((f) => f.type == FeatureType.marker).toList()
          ..sort((a, b) {
            final fa = floors[a.floorId]?.order ?? 0;
            final fb = floors[b.floorId]?.order ?? 0;
            return fa != fb ? fa.compareTo(fb) : a.name.compareTo(b.name);
          });
    final multiFloor = s.draft.floors.length > 1;
    final cards = [
      for (final m in markers)
        (
          title: m.name,
          subtitle: multiFloor ? floors[m.floorId]?.name ?? '' : '',
          link: markerLink(base, eventId, m.id),
        ),
    ];

    void print() {
      final html = qrPrintHtml(
        eventName: s.event.name,
        cards: cards,
        texts: (
          lang: Localizations.localeOf(context).languageCode,
          pageTitle: l10n.qrTitle,
          youAreHere: l10n.youAreHere,
          instructions: l10n.qrScanHint,
          printButton: l10n.qrPrint,
        ),
      );
      if (!(openPage ?? openPrintPage)(html)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.qrPopupBlocked)));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.qrTitle} · ${s.event.name}'),
        actions: [
          if (cards.isNotEmpty && (openPage != null || canOpenPrintPage))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilledButton.icon(
                onPressed: print,
                icon: const Icon(Icons.print_outlined),
                label: Text(l10n.qrPrint),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.qrIntro),
          if (s.event.publishedVersion == 0) ...[
            const SizedBox(height: 8),
            _Warning(l10n.qrNotPublished),
          ] else if (cards.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.qrPublishFirst,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          if (cards.isEmpty)
            _Warning(l10n.qrNone)
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [for (final c in cards) _QrTile(card: c)],
            ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: ListTile(leading: const Icon(Icons.info_outline), title: Text(text)),
  );
}

class _QrTile extends StatelessWidget {
  const _QrTile({required this.card});

  final QrCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = MapsLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(card.title, style: text.titleMedium),
              if (card.subtitle.isNotEmpty)
                Text(card.subtitle, style: text.bodySmall),
              const SizedBox(height: 8),
              // QR codes need a white background to scan in any theme.
              QrImageView(
                data: card.link,
                size: 180,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
              const SizedBox(height: 4),
              SelectableText(
                card.link,
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: card.link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(l10n.qrCopied)));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l10n.qrCopy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
