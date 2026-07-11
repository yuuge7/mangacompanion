import 'package:flutter/material.dart';

import '../models/manga_entry.dart';
import '../theme.dart';

/// Bottom sheet for adding or editing an entry. Returns the entry on save,
/// null on dismiss.
Future<MangaEntry?> showEditSheet(BuildContext context,
    {MangaEntry? initial}) {
  return showModalBottomSheet<MangaEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditSheet(initial: initial),
  );
}

class _EditSheet extends StatefulWidget {
  final MangaEntry? initial;
  const _EditSheet({this.initial});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _coverUrl;
  late final TextEditingController _readUrl;
  late final TextEditingController _currentCh;
  late final TextEditingController _totalCh;
  late String _status;
  String? _error;

  bool get isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _title = TextEditingController(text: e?.title ?? '');
    _coverUrl = TextEditingController(text: e?.coverUrl ?? '');
    _readUrl = TextEditingController(text: e?.readUrl ?? '');
    _currentCh = TextEditingController(
        text: e == null || e.currentChapter == 0 ? '' : '${e.currentChapter}');
    _totalCh = TextEditingController(
        text: e?.totalChapters == null ? '' : '${e!.totalChapters}');
    _status = e?.status ?? 'reading';
  }

  @override
  void dispose() {
    for (final c in [_title, _coverUrl, _readUrl, _currentCh, _totalCh]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    final entry = widget.initial?.copy() ?? MangaEntry.blank();
    entry.title = title;
    entry.coverUrl = _coverUrl.text.trim();
    entry.readUrl = _readUrl.text.trim();
    entry.currentChapter = int.tryParse(_currentCh.text.trim()) ?? 0;
    entry.totalChapters = int.tryParse(_totalCh.text.trim());
    entry.status = _status;
    entry.lastUpdated = DateTime.now().millisecondsSinceEpoch;
    Navigator.of(context).pop(entry);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6)),
      );

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
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
                Text(isEdit ? 'Edit Entry' : 'Add Entry',
                    style: const TextStyle(
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
            const SizedBox(height: 12),
            _label('Title *'),
            TextField(
              controller: _title,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: const InputDecoration(hintText: 'e.g. Berserk'),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12)),
              ),
            const SizedBox(height: 14),
            _label('Cover Image URL'),
            TextField(
              controller: _coverUrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: const InputDecoration(hintText: 'https://…'),
            ),
            const SizedBox(height: 14),
            _label('Read URL'),
            TextField(
              controller: _readUrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration:
                  const InputDecoration(hintText: 'Link to reading site'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Current Ch.'),
                      TextField(
                        controller: _currentCh,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14),
                        decoration: const InputDecoration(hintText: '0'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Total Chs.'),
                      TextField(
                        controller: _totalCh,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14),
                        decoration: const InputDecoration(hintText: '?'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _label('Status'),
            Row(
              children: [
                for (final (id, label) in [
                  ('reading', '📖 Reading'),
                  ('read', '✅ Read'),
                  ('dropped', '🚫 Dropped'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == id,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _status = id),
                      labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _status == id
                              ? AppColors.accentSoft
                              : AppColors.textFaint),
                      selectedColor: AppColors.accent.withValues(alpha: 0.14),
                      backgroundColor: AppColors.field,
                      side: BorderSide(
                          color: _status == id
                              ? AppColors.accent.withValues(alpha: 0.4)
                              : Colors.transparent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(isEdit ? 'Save Changes' : '+ Add Entry',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
