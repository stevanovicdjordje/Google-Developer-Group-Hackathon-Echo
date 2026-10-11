import 'dart:ui' show PathMetric;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../core/ui/ui.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

/// Top row of the organizer screens: 44 px round back button + a caption.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.caption,
    required this.onBack,
    this.onInk = false,
  });

  final Widget caption;
  final VoidCallback onBack;

  /// Draws the button for the dark (published) screen.
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final eho = context.eho;
    return Row(
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          style: IconButton.styleFrom(
            backgroundColor: onInk ? eho.inkOverlay : scheme.surface,
            foregroundColor: onInk ? eho.onInk : scheme.onSurface,
          ),
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        caption,
      ],
    );
  }
}

/// How many files the current draft was extracted from (the review's
/// "Extracted from 3 files" overline). 0 = unknown, the overline is hidden.
class OrganizerFileCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int count) => state = count;
}

final organizerFileCountProvider =
    NotifierProvider<OrganizerFileCountNotifier, int>(
      OrganizerFileCountNotifier.new,
    );

/// `/organizer`: upload unstructured files; the AI builds the event.
///
/// The optional parameters only seed a state for the dev screenshot routes:
/// [initialFiles] (already chosen) and [foundSoFar] (the extraction progress
/// state, with the bar at [progress]).
class OrganizerUploadScreen extends ConsumerStatefulWidget {
  const OrganizerUploadScreen({
    super.key,
    this.initialFiles = const [],
    this.foundSoFar,
    this.progress,
  });

  final List<UploadedFile> initialFiles;
  final EventDraft? foundSoFar;
  final double? progress;

  @override
  ConsumerState<OrganizerUploadScreen> createState() =>
      _OrganizerUploadScreenState();
}

class _OrganizerUploadScreenState extends ConsumerState<OrganizerUploadScreen> {
  late final _files = <UploadedFile>[...widget.initialFiles];
  late bool _working = widget.foundSoFar != null;

  /// Set once the extraction finished; drives the "found N stages…" line.
  late EventDraft? _found = widget.foundSoFar;

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
    ref.read(organizerFileCountProvider.notifier).set(_files.length);
    ref.read(organizerDraftProvider.notifier).set(draft);
    // Show what was found for a beat, then move on to the review.
    setState(() => _found = draft);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _working = false);
    context.go('/organizer/review');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final found = _found;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                caption: Text(
                  l10n.orgNewEvent,
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 18),
                  children: [
                    Text(l10n.orgUploadTitle, style: t.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      l10n.orgUploadBody,
                      style: t.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DropZone(
                      label: l10n.orgChooseFiles,
                      onTap: _working ? null : _pick,
                    ),
                    if (_files.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < _files.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _FileRow(file: _files[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_working) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: found == null ? null : widget.progress ?? 1,
                    color: scheme.primary,
                    backgroundColor: scheme.outlineVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  found == null
                      ? l10n.orgReading
                      : l10n.orgFoundSoFar(
                          l10n.orgStagesCount(found.stages.length),
                          l10n.orgSessionsCount(found.sessions.length),
                          l10n.orgSpeakersCount(found.speakers.length),
                        ),
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: Text(l10n.orgBuild),
                onPressed: _files.isEmpty || _working ? null : _extract,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The big dashed "Choose files" target.
class _DropZone extends StatelessWidget {
  const _DropZone({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        radius: 20,
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 132,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_outlined, size: 28, color: scheme.primary),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontSize: 16, color: scheme.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(1),
      );
    for (final PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// "412 KB", or "1.2 MB" from a megabyte up.
String _sizeLabel(AppLocalizations l10n, int bytes) {
  final kb = (bytes / 1024).ceil();
  if (kb < 1024) return l10n.orgFileSizeKb(kb);
  return l10n.orgFileSizeMb((bytes / (1024 * 1024)).toStringAsFixed(1));
}

/// One picked file: type badge, name, size.
class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final UploadedFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final dot = file.name.lastIndexOf('.');
    final ext = dot < 0 ? '' : file.name.substring(dot + 1).toLowerCase();
    final (bg, fg) = switch (ext) {
      'pdf' => (eho.liveContainer, eho.onLiveContainer),
      'xls' ||
      'xlsx' ||
      'csv' => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ => (eho.background, scheme.onSurfaceVariant),
    };
    // "xlsx" reads as "XLS" (same for docx, pptx), like the design.
    final short = ext.length == 4 && ext.endsWith('x')
        ? ext.substring(0, 3)
        : ext;
    final badge = (short.length > 4 ? short.substring(0, 4) : short)
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: badge.isEmpty
                ? Icon(Icons.description_outlined, size: 18, color: fg)
                : Text(
                    badge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sizeLabel(l10n, file.sizeBytes),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
    final l10n = AppLocalizations.of(context);
    if (draft == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/organizer'),
            child: Text(l10n.orgStartByUploading),
          ),
        ),
      );
    }
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fileCount = ref.watch(organizerFileCountProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                onBack: () => context.go('/organizer'),
                caption: Text(
                  l10n.orgReviewTitle,
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 16),
              if (fileCount > 0) ...[
                AiHint(
                  l10n.orgExtractedFrom(fileCount),
                  style: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                draft.name,
                style: t.headlineLarge?.copyWith(fontSize: 30, height: 1.05),
              ),
              const SizedBox(height: 6),
              Text(
                '${draft.dates} · ${draft.venue}',
                style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _CountTile(
                    count: draft.stages.length,
                    label: l10n.orgStagesCount(draft.stages.length),
                  ),
                  const SizedBox(width: 8),
                  _CountTile(
                    count: draft.sessions.length,
                    label: l10n.orgSessionsCount(draft.sessions.length),
                  ),
                  const SizedBox(width: 8),
                  _CountTile(
                    count: draft.speakers.length,
                    label: l10n.orgSpeakersCount(draft.speakers.length),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: draft.sessions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = draft.sessions[i];
                      return _SessionRow(
                        session: s,
                        onEdit: () => _edit(draft, s),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _publishing ? null : () => _publish(draft),
                child: _publishing
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onSurface.withValues(alpha: 0.38),
                        ),
                      )
                    : Text(l10n.orgPublish),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White tile with a big number and its unit ("3" / "stages").
class _CountTile extends StatelessWidget {
  const _CountTile({required this.count, required this.label});

  final int count;

  /// The localized plural including the number ("3 stages").
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The plural strings start with the number; the tile shows it big instead.
    final prefix = '$count';
    final unit = label.startsWith(prefix)
        ? label.substring(prefix.length).trim()
        : label;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prefix, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              unit,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One session in the review list. A session the AI could not place on a
/// stage is flagged (tinted row, live-colored hint and edit button).
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onEdit});

  final Session session;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    final s = session;
    final flagged = s.stage.trim().isEmpty;
    final speakers = s.speakers.map((p) => p.name).join(', ');
    final meta = flagged
        ? '${s.start}–${s.end} · ${l10n.orgCheckRoomMissing}'
        : '${s.start}–${s.end} · ${s.stage}'
              '${speakers.isEmpty ? '' : ' · $speakers'}';
    return Container(
      color: flagged ? eho.liveContainer.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: flagged
                        ? eho.onLiveContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: l10n.orgEditSession,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: flagged ? eho.liveContainer : eho.background,
              foregroundColor: flagged ? eho.onLiveContainer : scheme.onSurface,
            ),
            onPressed: onEdit,
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
      final l10n = AppLocalizations.of(context);
      setState(() {
        _titleError = badTitle ? l10n.orgTitleRequired : null;
        _timeError = badTime ? l10n.orgEndAfterStart : null;
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
    final l10n = AppLocalizations.of(context);
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
          Text(l10n.orgEditSession, style: t.textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.orgTitleLabel,
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
                  label: Text(l10n.orgStartTime(_start)),
                  onPressed: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(l10n.orgEndTime(_end)),
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
            decoration: InputDecoration(labelText: l10n.orgStageLabel),
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
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _save, child: Text(l10n.save)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Public host the join link is shown with (`--dart-define=LINK_BASE=...`,
/// the same setting `linkBase()` uses off the web); empty = the link's own.
const _publicLinkBase = String.fromEnvironment('LINK_BASE');

/// The join link as shown to people: no scheme, and the public host when one
/// is configured ("eho.app/e/devfest"). Display only: copy and QR keep the
/// full working [url].
String displayJoinLink(String url, {String publicBase = _publicLinkBase}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) {
    return url.replaceFirst(
      RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false),
      '',
    );
  }
  final public = publicBase.isEmpty ? null : Uri.tryParse(publicBase);
  final host = public != null && public.hasAuthority
      ? public.authority
      : uri.authority;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  final path = uri.path == '/' ? '' : uri.path;
  return '$host$path$query';
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
    final eho = context.eho;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: eho.ink,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(
                          onInk: true,
                          onBack: () => context.go('/organizer/review'),
                          caption: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: eho.live,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.orgPublished.toUpperCase(),
                                style: t.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: eho.onInkLive,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.orgIsLive(name),
                          style: t.displaySmall?.copyWith(
                            color: eho.onInk,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.orgShareBody,
                          style: t.bodyLarge?.copyWith(
                            fontSize: 16,
                            color: eho.onInkMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              // The QR needs a light ground to scan.
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: QrImageView(
                              data: url,
                              size: 220,
                              padding: EdgeInsets.zero,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: eho.ink,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: eho.ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                          decoration: BoxDecoration(
                            color: eho.inkOverlay,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  displayJoinLink(url),
                                  maxLines: 1,
                                  style: t.bodyMedium?.copyWith(
                                    color: eho.onInkPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                icon: const Icon(Icons.copy, size: 16),
                                label: Text(l10n.orgCopy),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  backgroundColor: eho.onInk,
                                  foregroundColor: eho.ink,
                                  textStyle: t.labelLarge,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: url));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.orgLinkCopied)),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go(Uri.parse(url).path),
                      child: Text(l10n.orgOpenAsAttendee),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
