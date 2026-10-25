import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'format.dart';
import 'importers.dart';
import 'models/manga_entry.dart';
import 'screens/import_preview.dart';

/// What an import changed, and how to take it back.
class ImportOutcome {
  final String message;
  final List<MangaEntry> before;
  const ImportOutcome(this.message, this.before);
}

/// Picks a file, shows the preview, and applies the user's choice.
///
/// Returns null when nothing changed (cancelled, or the file was unusable;
/// problems are reported with a snackbar here).
Future<ImportOutcome?> pickAndImport(
    BuildContext context, AppState state) async {
  void snack(String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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
  if (picked == null) return null;

  ParsedBackup? backup;
  try {
    // Mihon backups run to megabytes; parse off the UI thread.
    backup = await compute(parseBackupFile, await picked.readAsBytes());
  } catch (_) {
    snack('Could not read that file. Try picking it again.');
    return null;
  }
  if (backup == null) {
    snack('That is not a file this app can read. Use a backup from '
        'Manga Companion or Mihon, or a MyAnimeList or Anime-Planet export.');
    return null;
  }
  if (backup.entries.isEmpty) {
    snack('No manga found in that file.');
    return null;
  }
  if (!context.mounted) return null;

  final plan = state.planMerge(backup.entries);
  final mode = await showImportPreview(context,
      state: state, backup: backup, plan: plan);
  if (mode == null) return null;

  final before = state.snapshot();
  if (mode == ImportMode.replace) {
    await state.replaceAll(backup.entries);
    return ImportOutcome(
        'Replaced your shelf with ${titleCount(backup.entries.length)}',
        before);
  }
  await state.applyMerge(plan);
  return ImportOutcome(
      'Merged: ${plan.added.length} added, ${plan.updated.length} updated',
      before);
}
