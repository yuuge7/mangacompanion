import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../storage.dart';
import '../theme.dart';

Future<void> showSettingsSheet(BuildContext context, AppState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SettingsSheet(state: state),
  );
}

class _SettingsSheet extends StatelessWidget {
  final AppState state;
  const _SettingsSheet({required this.state});

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export(BuildContext context) async {
    final json = state.exportJson();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final name = 'manga-companion-$date.json';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(json);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: name,
    ));
  }

  Future<void> _import(BuildContext context) async {
    final picked = await openFile(acceptedTypeGroups: [
      const XTypeGroup(label: 'JSON backup', extensions: ['json'], mimeTypes: ['application/json']),
      const XTypeGroup(label: 'Any file'),
    ]);
    if (picked == null) return;
    String raw;
    try {
      raw = utf8.decode(await picked.readAsBytes());
    } catch (_) {
      if (context.mounted) _snack(context, 'Could not read that file');
      return;
    }
    final entries = MangaStore.parseExport(raw);
    if (entries == null || entries.isEmpty) {
      if (context.mounted) {
        _snack(context,
            'Not a valid backup file (expected a JSON array of entries)');
      }
      return;
    }
    if (!context.mounted) return;

    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.cardBorder)),
        title: const Text('Import entries',
            style: TextStyle(color: AppColors.text, fontSize: 17)),
        content: Text(
          'Found ${entries.length} entries in the file.\n\n'
          'Merge keeps your current list and updates/adds from the file. '
          'Replace wipes your list first.',
          style: const TextStyle(color: AppColors.textDim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textFaint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'replace'),
            child: const Text('Replace',
                style: TextStyle(color: AppColors.danger)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'merge'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Merge'),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;

    final added =
        await state.importEntries(entries, replace: mode == 'replace');
    if (!context.mounted) return;
    Navigator.of(context).pop(); // close the settings sheet
    _snack(
        context,
        mode == 'replace'
            ? 'Imported ${entries.length} entries (list replaced)'
            : 'Merged: $added new, ${entries.length - added} updated');
  }

  Widget _row(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      Color iconColor = AppColors.accent,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 19, color: iconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = state.entries.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                  color: AppColors.fieldBorder,
                  borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Settings',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('DATA MANAGEMENT',
              style: TextStyle(
                  color: AppColors.textGhost,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7)),
          const SizedBox(height: 12),
          _row(
            context,
            icon: Icons.file_download_outlined,
            title: 'Export data',
            subtitle:
                'Share your list as a JSON backup file',
            onTap: () => _export(context),
          ),
          _row(
            context,
            icon: Icons.file_upload_outlined,
            title: 'Import data',
            subtitle: 'Load a JSON backup file',
            onTap: () => _import(context),
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.18)),
            ),
            child: Text(
              '📚 $count ${count == 1 ? 'entry' : 'entries'} in your list',
              style: const TextStyle(
                  color: AppColors.accentSoft, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
