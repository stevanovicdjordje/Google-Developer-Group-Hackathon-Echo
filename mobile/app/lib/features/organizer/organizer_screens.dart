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

  Future<void> _edit(EventDraft draft, Session session) async {
    final edited = await showModalBottomSheet<Session>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SessionEditSheet(session: session, stages: draft.stages),
    );
    if (edited == null || !mounted) return;
    ref
        .read(organizerDraftProvider.notifier)
        .set(
          EventDraft(
            name: draft.name,
            dates: draft.dates,
            venue: draft.venue,
            stages: draft.stages,
            sessions: [
              for (final s in draft.sessions) s.id == edited.id ? edited : s,
            ],
            speakers: draft.speakers,
          ),
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
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit session',
                onPressed: () => _edit(draft, s),
              ),
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

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _timeOf(String hhmm) {
  final m = _minutes(hhmm);
  return TimeOfDay(hour: m ~/ 60, minute: m % 60);
}

/// Bottom sheet that edits a session's title, times and stage. Pops the
/// edited [Session], or null on cancel.
class _SessionEditSheet extends StatefulWidget {
  const _SessionEditSheet({required this.session, required this.stages});

  final Session session;
  final List<String> stages;

  @override
  State<_SessionEditSheet> createState() => _SessionEditSheetState();
}

class _SessionEditSheetState extends State<_SessionEditSheet> {
  late final _title = TextEditingController(text: widget.session.title);
  late String _start = widget.session.start;
  late String _end = widget.session.end;
  late String _stage = widget.session.stage;
  String? _titleError;
  String? _timeError;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOf(start ? _start : _end),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = _hhmm(picked);
      } else {
        _end = _hhmm(picked);
      }
      _timeError = null;
    });
  }

  void _save() {
    final title = _title.text.trim();
    final badTitle = title.isEmpty;
    final badTime = _minutes(_end) <= _minutes(_start);
    if (badTitle || badTime) {
      setState(() {
        _titleError = badTitle ? 'Title is required' : null;
        _timeError = badTime ? 'End must be after start' : null;
      });
      return;
    }
    final s = widget.session;
    Navigator.of(context).pop(
      Session(
        id: s.id,
        title: title,
        stage: _stage,
        start: _start,
        end: _end,
        speakers: s.speakers,
        description: s.description,
        track: s.track,
        isBreak: s.isBreak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // Keep the current stage selectable even if the draft's list lacks it.
    final stages = {...widget.stages, widget.session.stage}.toList();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit session', style: t.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: 'Title',
              border: const OutlineInputBorder(),
              errorText: _titleError,
            ),
            onChanged: (_) => setState(() => _titleError = null),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('Start $_start'),
                  onPressed: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('End $_end'),
                  onPressed: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
          if (_timeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _timeError!,
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _stage,
            decoration: const InputDecoration(
              labelText: 'Stage',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in stages)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _stage = v ?? _stage),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
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
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Link copied')));
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
