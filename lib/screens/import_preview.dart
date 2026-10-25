import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../importers.dart';
import '../models/manga_entry.dart';
import '../theme.dart';

enum ImportMode { merge, replace }

/// Shows what an import would do before anything changes. Returns the
/// chosen mode, or null on cancel.
Future<ImportMode?> showImportPreview(
  BuildContext context, {
  required AppState state,
  required ParsedBackup backup,
  required ImportPlan plan,
}) {
  return showDialog<ImportMode>(
    context: context,
    builder: (_) => _ImportPreview(state: state, backup: backup, plan: plan),
  );
}

class _ImportPreview extends StatelessWidget {
  final AppState state;
  final ParsedBackup backup;
  final ImportPlan plan;

  const _ImportPreview({
    required this.state,
    required this.backup,
    required this.plan,
  });

  String _chapterChange(MangaEntry next, Map<String, MangaEntry> shelf) {
    final mine = shelf[next.id];
    if (mine == null || mine.currentChapter == next.currentChapter) {
      return 'ch ${next.currentChapter}';
    }
    return 'ch ${mine.currentChapter} → ${next.currentChapter}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final shelf = state.entries.length;
    final byId = {for (final e in state.entries) e.id: e};
    return AlertDialog(
      title: Text('Import from ${backup.source.label}?'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The file holds ${titleCount(backup.entries.length)}. '
                'Merging would do this:',
                style: Type.bodySm.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: 10),
              _Group(
                label: 'New',
                items: [
                  for (final e in plan.added)
                    (e.title, 'ch ${e.currentChapter}'),
                ],
              ),
              _Group(
                label: 'Updated',
                items: [
                  for (final e in plan.updated)
                    (e.title, _chapterChange(e, byId)),
                ],
              ),
              _Group(
                label: 'Skipped, yours is newer',
                items: [
                  for (final e in plan.skipped) (e.title, ''),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                plan.changesAnything
                    ? 'Replace instead throws away '
                        '${shelf == 1 ? 'the 1 title' : 'all $shelf titles'} '
                        'on your shelf and keeps only the file.'
                    : 'Your shelf already has everything in this file. '
                        'Replace would throw it away and keep only the file.',
                style: Type.meta.copyWith(color: t.inkFaint, height: 1.5),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ImportMode.replace),
          style: TextButton.styleFrom(foregroundColor: t.danger),
          child: const Text('Replace'),
        ),
        FilledButton(
          onPressed: plan.changesAnything
              ? () => Navigator.pop(context, ImportMode.merge)
              : null,
          child: const Text('Merge'),
        ),
      ],
    );
  }
}

/// One line of the summary — label and count — that opens to list the
/// titles behind the count.
class _Group extends StatefulWidget {
  final String label;

  /// Title and a short note shown beside it.
  final List<(String, String)> items;

  const _Group({required this.label, required this.items});

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  static const _shown = 50;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final items = widget.items;
    final canOpen = items.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: canOpen,
          expanded: canOpen ? _open : null,
          label: '${widget.label}, ${items.length}',
          excludeSemantics: true,
          child: InkWell(
            onTap: canOpen ? () => setState(() => _open = !_open) : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.rule)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.label,
                        style: Type.bodySm.copyWith(color: t.inkMuted)),
                  ),
                  Text('${items.length}',
                      style: Type.numberSm.copyWith(
                          fontSize: 15,
                          color: canOpen ? t.ink : t.inkGhost)),
                  SizedBox(
                    width: 28,
                    child: canOpen
                        ? Icon(
                            _open
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: t.inkFaint)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open) ...[
          for (final (title, note) in items.take(_shown))
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 0, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.bodySm.copyWith(color: t.ink)),
                  ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(note,
                          style: Type.meta.copyWith(color: t.inkFaint)),
                    ),
                ],
              ),
            ),
          if (items.length > _shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 0, 0),
              child: Text('and ${groupDigits(items.length - _shown)} more',
                  style: Type.meta.copyWith(color: t.inkFaint)),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
