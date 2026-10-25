import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models/manga_entry.dart';
import '../theme.dart';
import '../widgets/sheet.dart';

/// Bottom sheet for adding or editing a title. Returns the entry on save,
/// null on dismiss. [state] is only read, to warn about duplicates.
Future<MangaEntry?> showEditSheet(
  BuildContext context, {
  required AppState state,
  MangaEntry? initial,
}) {
  return showModalBottomSheet<MangaEntry>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditSheet(state: state, initial: initial),
  );
}

class _EditSheet extends StatefulWidget {
  final AppState state;
  final MangaEntry? initial;
  const _EditSheet({required this.state, this.initial});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _coverUrl;
  late final TextEditingController _readUrl;
  late final TextEditingController _currentCh;
  late final TextEditingController _totalCh;
  late final TextEditingController _rereads;
  late ShelfStatus _status;
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
    _rereads = TextEditingController(
        text: e == null || e.rereads == 0 ? '' : '${e.rereads}');
    _status = e?.status ?? ShelfStatus.reading;
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _coverUrl,
      _readUrl,
      _currentCh,
      _totalCh,
      _rereads,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  MangaEntry? get _duplicate =>
      widget.state.findDuplicate(_title.text, exceptId: widget.initial?.id);

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the title a name so you can find it.');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final chapter = int.tryParse(_currentCh.text.trim()) ?? 0;
    final total = int.tryParse(_totalCh.text.trim());
    final rereads = int.tryParse(_rereads.text.trim()) ?? 0;

    final initial = widget.initial;
    final MangaEntry entry;
    if (initial == null) {
      // The chapter typed here was read before the app knew about it, so
      // it is not logged as today's reading.
      entry = MangaEntry.blank().copyWith(
        title: title,
        coverUrl: _coverUrl.text.trim(),
        readUrl: _readUrl.text.trim(),
        currentChapter: chapter,
        totalChapters: total,
        status: _status,
        rereads: rereads,
        finishedAt: _status == ShelfStatus.read ? now : null,
      );
    } else {
      entry = initial
          .copyWith(
            title: title,
            coverUrl: _coverUrl.text.trim(),
            readUrl: _readUrl.text.trim(),
            totalChapters: total,
            rereads: rereads,
          )
          .recordProgress(chapter, now: now)
          .moveTo(_status, now: now)
          .copyWith(lastUpdated: now);
    }
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

  /// Five shelves do not fit one row of segments on a phone, so each is a
  /// ruled tab that wraps. The chosen one is outlined in ink, not tinted
  /// with the accent.
  Widget _statusPicker() {
    final t = context.tk;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in ShelfStatus.values)
          Semantics(
            button: true,
            selected: _status == s,
            label: s.label,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: const BorderRadius.all(R.control),
              onTap: () => setState(() => _status = s),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _status == s ? t.raised : Colors.transparent,
                  borderRadius: const BorderRadius.all(R.control),
                  border: Border.all(
                    color: _status == s ? t.ink : t.rule,
                    width: _status == s ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  s.label,
                  style: Type.label
                      .copyWith(color: _status == s ? t.ink : t.inkFaint),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _historyLine(String label, String value) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child:
                Text(label, style: Type.bodySm.copyWith(color: t.inkMuted)),
          ),
          Text(value, style: Type.meta.copyWith(color: t.ink)),
        ],
      ),
    );
  }

  /// Read-only record for an existing title: when it was started and
  /// finished, and the last few logged steps.
  Widget _history(MangaEntry e) {
    final t = context.tk;
    final recent = e.history.reversed.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('History'),
        const SizedBox(height: 4),
        _historyLine('Added', shortDate(e.addedAt)),
        _historyLine('Started', shortDate(e.startedAt)),
        _historyLine('Finished', shortDate(e.finishedAt)),
        const SizedBox(height: 6),
        if (recent.isEmpty)
          Text('Chapters you log from now on show up here.',
              style: Type.bodySm.copyWith(color: t.inkFaint))
        else
          for (final ev in recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(shortDate(ev.at),
                        style: Type.meta.copyWith(color: t.inkFaint)),
                  ),
                  Text('ch ${ev.from} → ${ev.to}',
                      style: Type.meta.copyWith(color: t.ink)),
                ],
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final insets = MediaQuery.viewInsetsOf(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    final dup = _duplicate;
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
                  onChanged: (_) => setState(() => _error = null),
                ),
                if (dup != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: t.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '"${dup.title}" is already on your '
                              '${dup.status.label.toLowerCase()} shelf, at '
                              'chapter ${dup.currentChapter}.',
                              style: Type.bodySm.copyWith(color: t.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                        hint: 'blank if ongoing',
                        numeric: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _field(
                  label: 'Times re-read',
                  controller: _rereads,
                  hint: '0',
                  numeric: true,
                  keyboardType: TextInputType.number,
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
                    child: Text(switch ((isEdit, dup != null)) {
                      (false, false) => 'Add to shelf',
                      (false, true) => 'Add anyway',
                      (true, false) => 'Save changes',
                      (true, true) => 'Save anyway',
                    }),
                  ),
                ),
                if (widget.initial case final e?) ...[
                  const SizedBox(height: 28),
                  _history(e),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
