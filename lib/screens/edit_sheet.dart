import 'package:flutter/material.dart';

import '../models/manga_entry.dart';
import '../theme.dart';
import '../widgets/sheet.dart';

/// Bottom sheet for adding or editing a title. Returns the entry on save,
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
      setState(() => _error = 'Give the title a name so you can find it.');
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool numeric = false,
    bool autofocus = false,
    TextCapitalization capitalization = TextCapitalization.none,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    final t = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          onChanged: onChanged,
          style: (numeric ? Type.numberSm.copyWith(fontSize: 15) : Type.body)
              .copyWith(color: t.ink),
          decoration: InputDecoration(hintText: hint, errorText: errorText),
        ),
      ],
    );
  }

  /// Segmented status control. Replaces the stock chips: square-ish, ruled,
  /// and the selected one is filled with ink rather than tinted with accent.
  Widget _statusPicker() {
    final t = context.tk;
    return Row(
      children: [
        for (final (i, (id, label)) in const [
          ('reading', 'Reading'),
          ('read', 'Read'),
          ('dropped', 'Dropped'),
        ].indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: _status == id,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => setState(() => _status = id),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _status == id ? t.raised : Colors.transparent,
                    border: Border(
                      top: BorderSide(color: t.rule),
                      // Selection is marked the same way the status rail
                      // marks it: an ink underline, not a filled block.
                      bottom: BorderSide(
                        color: _status == id ? t.ink : t.rule,
                        width: _status == id ? 2 : 1,
                      ),
                      left: BorderSide(color: t.rule),
                      right:
                          i == 2 ? BorderSide(color: t.rule) : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    label,
                    style: Type.label.copyWith(
                      color: _status == id ? t.ink : t.inkFaint,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SheetScaffold(
          title: isEdit ? 'Edit title' : 'Add a title',
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(
                  label: 'Title',
                  controller: _title,
                  hint: 'Berserk',
                  autofocus: !isEdit,
                  capitalization: TextCapitalization.words,
                  errorText: _error,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 18),
                _field(
                  label: 'Where you read it',
                  controller: _readUrl,
                  hint: 'https://…',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 18),
                _field(
                  label: 'Cover image link',
                  controller: _coverUrl,
                  hint: 'https://…',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        label: 'Chapter you are on',
                        controller: _currentCh,
                        hint: '0',
                        numeric: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _field(
                        label: 'Chapters in total',
                        controller: _totalCh,
                        hint: 'leave blank if ongoing',
                        numeric: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionLabel('Shelf'),
                const SizedBox(height: 8),
                _statusPicker(),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(isEdit ? 'Save changes' : 'Add to shelf'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
