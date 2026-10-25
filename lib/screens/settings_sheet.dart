import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../file_export.dart';
import '../format.dart';
import '../importers.dart';
import '../theme.dart';
import '../widgets/sheet.dart';
import '../widgets/undo_snack.dart';
import 'import_preview.dart';

Future<void> showSettingsSheet(BuildContext context, AppState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SettingsSheet(state: state),
  );
}

class _SettingsSheet extends StatefulWidget {
  final AppState state;
  const _SettingsSheet({required this.state});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  /// 'export' or 'import' while that job is running; null when idle. Both
  /// rows lock during either, since both touch the same list.
  String? _busy;

  AppState get state => widget.state;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    setState(() => _busy = 'export');
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final saved = await saveTextFile(
        fileName: 'manga-companion-$date.json',
        content: state.exportJson(),
        mimeType: 'application/json',
      );
      if (saved == null) return; // picker dismissed
      _snack('Saved $saved');
    } on PlatformException {
      // Never show the platform's own message: it names Android internals.
      _snack('Could not write the file. Pick a different folder and try '
          'again.');
    } catch (_) {
      _snack('Could not write the file. Pick a different folder and try '
          'again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = 'import');
    try {
      final picked = await openFile(acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Backups and exports',
          extensions: ['json', 'xml', 'gz', 'tachibk', 'proto'],
          mimeTypes: [
            'application/json',
            'application/xml',
            'text/xml',
            'application/gzip',
            'application/x-gzip',
            'application/octet-stream',
          ],
        ),
        const XTypeGroup(label: 'Any file'),
      ]);
      if (picked == null) return;

      ParsedBackup? backup;
      try {
        // Mihon backups run to megabytes; parse off the UI thread.
        backup = await compute(parseBackupFile, await picked.readAsBytes());
      } catch (_) {
        _snack('Could not read that file. Try picking it again.');
        return;
      }
      if (backup == null) {
        _snack('That is not a file this app can read. Use a backup from '
            'Manga Companion or Mihon, or a MyAnimeList or Anime-Planet '
            'export.');
        return;
      }
      if (backup.entries.isEmpty) {
        _snack('No manga found in that file.');
        return;
      }
      if (!mounted) return;

      final plan = state.planMerge(backup.entries);
      final mode = await showImportPreview(context,
          state: state, backup: backup, plan: plan);
      if (mode == null || !mounted) return;

      final before = state.snapshot();
      final String message;
      if (mode == ImportMode.replace) {
        await state.replaceAll(backup.entries);
        message =
            'Replaced your shelf with ${titleCount(backup.entries.length)}';
      } else {
        await state.applyMerge(plan);
        message = 'Merged: ${plan.added.length} added, '
            '${plan.updated.length} updated';
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // close settings, show the result on top
      showUndoSnack(context,
          message: message, onUndo: () => state.replaceAll(before));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required String id,
    required VoidCallback onTap,
  }) {
    final t = context.tk;
    final running = _busy == id;
    final locked = _busy != null;
    return Semantics(
      button: true,
      enabled: !locked,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: locked ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.rule)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: locked ? t.inkGhost : t.inkMuted),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Type.label.copyWith(
                            fontSize: 14,
                            color: locked ? t.inkFaint : t.ink)),
                    const SizedBox(height: 3),
                    Text(running ? 'Working…' : subtitle,
                        style: Type.bodySm.copyWith(color: t.inkFaint)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 18,
                height: 18,
                child: running
                    ? CircularProgressIndicator(
                        strokeWidth: 2, color: t.inkMuted)
                    : Icon(Icons.chevron_right_rounded,
                        size: 18, color: locked ? t.inkGhost : t.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final count = state.entries.length;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SheetScaffold(
        title: 'Settings',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: SectionLabel('Your data'),
              ),
              _row(
                icon: Icons.file_download_outlined,
                title: 'Export a backup',
                subtitle: 'Write your shelf to a JSON file',
                id: 'export',
                onTap: _export,
              ),
              _row(
                icon: Icons.file_upload_outlined,
                title: 'Import a backup',
                subtitle: 'From this app, Mihon, MyAnimeList or Anime-Planet',
                id: 'import',
                onTap: _import,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Text(
                  '${titleCount(count)} · '
                  '${groupDigits(state.totalChaptersRead)} chapters, kept on '
                  'this phone only.',
                  style: Type.meta.copyWith(color: t.inkFaint, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
