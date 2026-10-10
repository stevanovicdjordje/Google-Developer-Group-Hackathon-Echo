import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';

/// `/organizer`: upload unstructured files; the AI builds the event.
class OrganizerUploadScreen extends ConsumerStatefulWidget {
  const OrganizerUploadScreen({super.key});

  @override
  ConsumerState<OrganizerUploadScreen> createState() =>
      _OrganizerUploadScreenState();
}

class _OrganizerUploadScreenState extends ConsumerState<OrganizerUploadScreen> {
  final _files = <UploadedFile>[];
  bool _working = false;

  Future<void> _pick() async {
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty) return;
    final files = [
      for (final f in picked)
        UploadedFile(name: f.name, sizeBytes: await f.xFile.length()),
    ];
    if (!mounted) return;
    setState(() => _files.addAll(files));
  }

  Future<void> _extract() async {
    setState(() => _working = true);
    final draft = await ref.read(organizerRepositoryProvider).extract(_files);
    if (!mounted) return;
    ref.read(organizerDraftProvider.notifier).set(draft);
    setState(() => _working = false);
    context.go('/organizer/review');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New event')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Drop in whatever you have', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Agenda PDFs, speaker spreadsheets, venue plans, slides. '
            'Eho reads them and builds your event.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose files'),
            onPressed: _working ? null : _pick,
          ),
          const SizedBox(height: 12),
          for (final f in _files)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(f.name),
              subtitle: Text('${(f.sizeBytes / 1024).ceil()} KB'),
            ),
          const SizedBox(height: 24),
          if (_working) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Reading your files and extracting stages, sessions and speakers…',
              style: t.bodyMedium,
            ),
          ] else
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Build my event with AI'),
              onPressed: _files.isEmpty ? null : _extract,
            ),
        ],
      ),
    );
  }
}

/// `/organizer/review`: what the AI extracted, then publish.
class OrganizerReviewScreen extends ConsumerStatefulWidget {
  const OrganizerReviewScreen({super.key});

  @override
  ConsumerState<OrganizerReviewScreen> createState() =>
      _OrganizerReviewScreenState();
}

class _OrganizerReviewScreenState extends ConsumerState<OrganizerReviewScreen> {
  bool _publishing = false;

  Future<void> _publish(EventDraft draft) async {
    setState(() => _publishing = true);
    final link = await ref.read(organizerRepositoryProvider).publish(draft);
    if (!mounted) return;
    context.go(
      '/organizer/published?url=${Uri.encodeComponent(link.url)}'
      '&name=${Uri.encodeComponent(draft.name)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(organizerDraftProvider);
    if (draft == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/organizer'),
            child: const Text('Start by uploading files'),
          ),
        ),
      );
    }
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Review your event')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(draft.name, style: t.headlineSmall),
          Text('${draft.dates} · ${draft.venue}', style: t.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('${draft.stages.length} stages')),
              Chip(label: Text('${draft.sessions.length} sessions')),
              Chip(label: Text('${draft.speakers.length} speakers')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Sessions', style: t.titleMedium),
          for (final s in draft.sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.title),
              subtitle: Text(
                '${s.start}–${s.end} · ${s.stage} · '
                '${s.speakers.map((p) => p.name).join(', ')}',
              ),
              trailing: const Icon(Icons.edit_outlined),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _publishing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.publish),
            label: const Text('Publish & get join link'),
            onPressed: _publishing ? null : () => _publish(draft),
          ),
        ],
      ),
    );
  }
}

/// `/organizer/published`: the join link and QR code.
class OrganizerPublishedScreen extends StatelessWidget {
  const OrganizerPublishedScreen({
    super.key,
    required this.url,
    required this.name,
  });

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Published')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('$name is live', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Share this link or print the QR code. Attendees join in one tap, '
            'in the app or the browser.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: url, size: 220),
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: t.titleMedium?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Link copied')));
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open as attendee'),
            onPressed: () => context.go(Uri.parse(url).path),
          ),
        ],
      ),
    );
  }
}
