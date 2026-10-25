import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../format.dart';
import '../import_flow.dart';
import '../models/manga_entry.dart';
import '../theme.dart';
import '../widgets/sheet.dart';
import '../widgets/shelf_row.dart';
import '../widgets/undo_snack.dart';
import 'edit_sheet.dart';
import 'settings_sheet.dart';
import 'stats_sheet.dart';

/// The shelf.
///
/// Statuses are filters over one list, not destinations, so they sit in a
/// rail at the top rather than in a bottom bar — which also keeps the
/// loudest thing on screen away from navigation. While sorted by recent
/// activity, the reading list is banded by how long a title has sat
/// untouched, because that is the question this app can answer and a
/// catalogue cannot.
class HomeScreen extends StatefulWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ShelfStatus _tab = ShelfStatus.reading;
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  /// Ids picked with a long-press. Non-empty means selection mode.
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  AppState get state => widget.state;

  static const _sortLabels = {
    SortMode.recent: 'recent',
    SortMode.title: 'title',
    SortMode.progress: 'progress',
    SortMode.rating: 'rating',
  };

  @override
  void initState() {
    super.initState();
    state.addListener(_onState);
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    state.removeListener(_onState);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onState() => setState(() {
        // Titles can vanish underneath a selection (undo, widget, import).
        _selected.removeWhere((id) => state.byId(id) == null);
      });

  // --------------------------------------------------------------- actions

  Future<void> _addEntry() async {
    final entry = await showEditSheet(context, state: state);
    if (entry == null) return;
    await state.add(entry);
    if (mounted && entry.status != _tab) setState(() => _tab = entry.status);
  }

  Future<void> _editEntry(MangaEntry item) async {
    final updated = await showEditSheet(context, state: state, initial: item);
    if (updated != null) await state.update(updated);
  }

  // Undo stands in for a confirmation dialog: one tap to act, one to take
  // it back.
  Future<void> _delete(MangaEntry item) async {
    final removed = await state.remove(item.id);
    if (removed == null || !mounted) return;
    showUndoSnack(context,
        message: 'Deleted ${item.title}',
        onUndo: () => state.restoreRemoved(removed));
  }

  Future<void> _move(MangaEntry item, ShelfStatus status) async {
    final before = await state.setStatus(item.id, status);
    if (before == null || !mounted) return;
    showUndoSnack(context,
        message: 'Moved ${item.title} to ${status.label.toLowerCase()}',
        onUndo: () => state.update(before));
  }

  Future<void> _reread(MangaEntry item) async {
    final before = await state.startReread(item.id);
    if (before == null || !mounted) return;
    showUndoSnack(context,
        message: 'Started ${item.title} again from chapter 0',
        onUndo: () => state.update(before));
  }

  Future<void> _bump(MangaEntry item, int dir) async {
    final before = await state.bumpChapter(item.id, dir);
    if (before == null || !mounted) return;
    if (dir > 0) await HapticFeedback.selectionClick();
    final after = state.byId(item.id);
    // Logging a chapter on a planned or paused title starts it again.
    if (mounted && after != null && after.status != before.status) {
      showUndoSnack(context,
          message: 'Moved ${item.title} to reading',
          onUndo: () => state.update(before));
    }
  }

  Future<void> _importFromOnboarding() async {
    final outcome = await pickAndImport(context, state);
    if (outcome == null || !mounted) return;
    showUndoSnack(context,
        message: outcome.message,
        onUndo: () => state.replaceAll(outcome.before));
  }

  // ------------------------------------------------------------- selection

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  void _clearSelection() => setState(_selected.clear);

  void _selectAll() => setState(() {
        _selected.addAll(state.visible(_tab, _searchCtrl.text).map((e) => e.id));
      });

  Future<void> _bulkMove(ShelfStatus status) async {
    final ids = Set.of(_selected);
    final before = state.snapshot();
    _clearSelection();
    await state.setStatusMany(ids, status);
    if (!mounted) return;
    showUndoSnack(context,
        message: 'Moved ${titleCount(ids.length)} to '
            '${status.label.toLowerCase()}',
        onUndo: () => state.replaceAll(before));
  }

  Future<void> _bulkDelete() async {
    final ids = Set.of(_selected);
    final before = state.snapshot();
    _clearSelection();
    await state.removeMany(ids);
    if (!mounted) return;
    showUndoSnack(context,
        message: 'Deleted ${titleCount(ids.length)}',
        onUndo: () => state.replaceAll(before));
  }

  // ---------------------------------------------------------------- header

  Widget _iconButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    double size = 20,
  }) {
    return Tooltip(
      message: label,
      child: InkResponse(
        radius: 24,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Semantics(
            button: true,
            label: label,
            child: Icon(icon, size: size, color: context.tk.inkMuted),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    if (_selecting) return _selectionBar();
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: _searching
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: Type.body.copyWith(color: t.ink),
                    decoration: const InputDecoration(
                      hintText: 'Search your shelf',
                    ),
                  )
                : Text(
                    'Manga Companion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.display.copyWith(color: t.ink),
                  ),
          ),
          const SizedBox(width: 4),
          if (state.entries.isNotEmpty)
            _iconButton(
              _searching ? Icons.close_rounded : Icons.search_rounded,
              _searching ? 'Close search' : 'Search your shelf',
              () => setState(() {
                _searching = !_searching;
                if (!_searching) _searchCtrl.clear();
              }),
            ),
          if (!_searching) ...[
            _iconButton(Icons.add_rounded, 'Add a title', _addEntry, size: 24),
            SizedBox(
              width: 44,
              height: 44,
              child: PopupMenuButton<String>(
                tooltip: 'More',
                position: PopupMenuPosition.under,
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: t.inkMuted),
                onSelected: (v) {
                  if (v == 'stats') showStatsSheet(context, state);
                  if (v == 'settings') showSettingsSheet(context, state);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'stats', height: 44, child: Text('Stats')),
                  PopupMenuItem(
                      value: 'settings', height: 44, child: Text('Settings')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Replaces the header while titles are picked: count on the left,
  /// what can be done to all of them on the right.
  Widget _selectionBar() {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          _iconButton(Icons.close_rounded, 'Stop selecting', _clearSelection),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                '${_selected.length} selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.display.copyWith(fontSize: 18, color: t.ink),
              ),
            ),
          ),
          _iconButton(
              Icons.select_all_rounded, 'Select all on this shelf', _selectAll),
          SizedBox(
            width: 44,
            height: 44,
            child: PopupMenuButton<ShelfStatus>(
              tooltip: 'Move selected',
              position: PopupMenuPosition.under,
              icon: Icon(Icons.drive_file_move_outline,
                  size: 20, color: t.inkMuted),
              onSelected: _bulkMove,
              itemBuilder: (_) => [
                for (final s in ShelfStatus.values)
                  if (s != _tab)
                    PopupMenuItem(
                      value: s,
                      height: 44,
                      child: Text('Move to ${s.label.toLowerCase()}'),
                    ),
              ],
            ),
          ),
          _iconButton(
              Icons.delete_outline_rounded, 'Delete selected', _bulkDelete),
        ],
      ),
    );
  }

  /// Status rail. Counts are the point, so they are set large in mono; the
  /// active filter is marked by an ink underline, never by the accent.
  /// Five shelves do not fit a phone's width at large text, so it scrolls.
  Widget _rail() {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [for (final s in ShelfStatus.values) _railTab(s)],
                ),
              ),
            ),
            _sortControl(),
          ],
        ),
      ),
    );
  }

  Widget _railTab(ShelfStatus s) {
    final t = context.tk;
    final active = _tab == s;
    final count = state.countFor(s);
    return Semantics(
      button: true,
      selected: active,
      label: '${s.label}, ${titleCount(count)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => setState(() {
          _tab = s;
          _selected.clear();
        }),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52, minWidth: 52),
          margin: const EdgeInsets.only(right: 18),
          padding: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? t.ink : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.rail,
                maxLines: 1,
                style: Type.eyebrow
                    .copyWith(color: active ? t.inkMuted : t.inkGhost),
              ),
              const SizedBox(height: 3),
              Text(
                '$count',
                style: Type.number.copyWith(
                  fontSize: 20,
                  color: active ? t.ink : t.inkGhost,
                ),
              ),
              const SizedBox(height: 7),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortControl() {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 6),
      child: PopupMenuButton<SortMode>(
        tooltip: 'Sort the shelf',
        position: PopupMenuPosition.under,
        onSelected: state.setSort,
        itemBuilder: (_) => [
          for (final (mode, label) in [
            (SortMode.recent, 'Recent activity'),
            (SortMode.title, 'Title A–Z'),
            (SortMode.progress, 'Progress'),
            (SortMode.rating, 'Rating'),
          ])
            PopupMenuItem(
              value: mode,
              height: 44,
              child: Row(children: [
                SizedBox(
                  width: 24,
                  child: state.sortMode == mode
                      ? Icon(Icons.check_rounded, size: 15, color: t.ink)
                      : null,
                ),
                Text(label),
              ]),
            ),
        ],
        child: Semantics(
          button: true,
          label: 'Sort the shelf, currently ${_sortLabels[state.sortMode]}',
          excludeSemantics: true,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(R.control),
              border: Border.all(color: t.rule),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_vert_rounded, size: 14, color: t.inkFaint),
              const SizedBox(width: 4),
              Text(_sortLabels[state.sortMode]!,
                  style: Type.meta.copyWith(color: t.inkFaint)),
            ]),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- bands

  /// Bands only make sense while the list is ordered by activity, and only
  /// on the reading tab where "untouched for a month" means something.
  bool get _banded =>
      _tab == ShelfStatus.reading && state.sortMode == SortMode.recent;

  static String _bandFor(int lastUpdated) {
    final now = DateTime.now();
    final startOfToday =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    if (lastUpdated >= startOfToday) return 'TODAY';
    final age = now.millisecondsSinceEpoch - lastUpdated;
    if (age < 7 * 86400000) return 'THIS WEEK';
    if (age < 30 * 86400000) return 'EARLIER THIS MONTH';
    return 'OLDER';
  }

  Widget _bandHeader(String label, int count) {
    final t = context.tk;
    return Container(
      color: t.groundSunken,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Type.eyebrow.copyWith(color: t.inkFaint)),
          ),
          Text('$count', style: Type.meta.copyWith(color: t.inkGhost)),
        ],
      ),
    );
  }

  Widget _footer(List<MangaEntry> list) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Row(
        children: [
          Expanded(
            child: Text(titleCount(list.length),
                style: Type.meta.copyWith(color: t.inkGhost)),
          ),
          Text('${groupDigits(state.chaptersIn(list))} chapters',
              style: Type.meta.copyWith(color: t.inkGhost)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- states

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final t = context.tk;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: t.inkGhost),
            const SizedBox(height: 16),
            Text(title, style: Type.display.copyWith(fontSize: 19, color: t.ink)),
            const SizedBox(height: 7),
            Text(body, style: Type.bodySm.copyWith(color: t.inkMuted)),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  /// First run, or a shelf emptied out: two ways in, and the few things
  /// worth knowing that the interface cannot show on its own.
  Widget _onboarding() {
    final t = context.tk;
    Widget tip(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: t.inkFaint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: Type.bodySm.copyWith(color: t.inkMuted)),
              ),
            ],
          ),
        );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Start your shelf',
                  style: Type.display.copyWith(fontSize: 24, color: t.ink)),
              const SizedBox(height: 8),
              Text(
                'Track the chapter you are on for every manga you read, '
                'and pick up where you left off on the site you read it on.',
                style: Type.body.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add your first title'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _importFromOnboarding,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Import a backup or list'),
              ),
              const SizedBox(height: 8),
              Text(
                'Reads Manga Companion and Mihon backups, and MyAnimeList '
                'and Anime-Planet exports.',
                style: Type.meta.copyWith(color: t.inkFaint, height: 1.5),
              ),
              const SizedBox(height: 32),
              const SectionLabel('Good to know'),
              tip(Icons.swipe_right_alt_rounded,
                  'Swipe a title right to log a chapter, left to mark it read.'),
              tip(Icons.touch_app_outlined,
                  'Long-press a title to select several at once.'),
              tip(Icons.widgets_outlined,
                  'Add the Reading widget to your home screen to log '
                  'chapters without opening the app.'),
              tip(Icons.lock_outline_rounded,
                  'Everything stays on this phone. Export a backup from '
                  'Settings now and then.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    if (_searchCtrl.text.trim().isNotEmpty) {
      return _message(
        icon: Icons.search_off_rounded,
        title: 'No matches here',
        body: 'Nothing on the ${_tab.label.toLowerCase()} shelf matches '
            '"${_searchCtrl.text.trim()}". Try fewer words, or look in '
            'another tab.',
        actionLabel: 'Clear search',
        onAction: () => setState(() {
          _searchCtrl.clear();
          _searching = false;
        }),
      );
    }
    return switch (_tab) {
      ShelfStatus.read => _message(
          icon: Icons.done_all_rounded,
          title: 'Nothing finished yet',
          body: 'Catch up to the last chapter of a title and it moves here, '
              'where you can rate it.',
        ),
      ShelfStatus.dropped => _message(
          icon: Icons.remove_circle_outline_rounded,
          title: 'Nothing dropped',
          body: 'Titles you give up on land here. They keep their chapter '
              'count in case you come back.',
        ),
      ShelfStatus.onHold => _message(
          icon: Icons.pause_circle_outline_rounded,
          title: 'Nothing on hold',
          body: 'Park a title here while you wait for more chapters. '
              'Logging a chapter puts it back on reading.',
        ),
      ShelfStatus.planned => _message(
          icon: Icons.bookmark_add_outlined,
          title: 'Nothing planned',
          body: 'Keep titles you mean to start here. Log the first chapter '
              'and it moves to reading.',
        ),
      ShelfStatus.reading => _message(
          icon: Icons.bookmark_border_rounded,
          title: 'Nothing in progress',
          body: 'Add a title with its cover, the site you read it on, and '
              'the chapter you are on.',
          actionLabel: 'Add a title',
          onAction: _addEntry,
        ),
    };
  }

  // ------------------------------------------------------------------ list

  /// Swipe right to log a chapter (or mark read once caught up), left to
  /// mark read. The row springs back; the action shows in the row itself.
  Widget _swipeable(MangaEntry item, Widget child) {
    if (_selecting || !item.status.tracksProgress) return child;
    return Dismissible(
      key: ValueKey('swipe-${item.id}'),
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.4,
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && !item.isDone) {
          await _bump(item, 1);
        } else {
          await _move(item, ShelfStatus.read);
        }
        return false;
      },
      background: _swipeBackground(
        alignment: Alignment.centerLeft,
        icon: item.isDone ? Icons.check_rounded : Icons.add_rounded,
        label: item.isDone ? 'Mark read' : 'Chapter ${item.currentChapter + 1}',
        done: item.isDone,
      ),
      secondaryBackground: _swipeBackground(
        alignment: Alignment.centerRight,
        icon: Icons.check_rounded,
        label: 'Mark read',
        done: true,
      ),
      child: child,
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required IconData icon,
    required String label,
    required bool done,
  }) {
    final t = context.tk;
    final color = done ? t.done : t.ink;
    final left = alignment == Alignment.centerLeft;
    return Container(
      color: t.raised,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: left ? TextDirection.ltr : TextDirection.rtl,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 8),
          Text(label, style: Type.label.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _list(List<MangaEntry> list) {
    // Band headers (as strings) between rows, flattened into one list so
    // the whole shelf scrolls as a single column. Only these light slots
    // are made up front; row widgets are built as they scroll into view.
    final slots = <Object>[];
    final bandCounts = <String, int>{};
    if (_banded) {
      for (final e in list) {
        final b = _bandFor(e.lastUpdated);
        bandCounts[b] = (bandCounts[b] ?? 0) + 1;
      }
    }
    String? band;
    for (final item in list) {
      if (_banded) {
        final b = _bandFor(item.lastUpdated);
        if (b != band) {
          band = b;
          slots.add(b);
        }
      }
      slots.add(item);
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: slots.length + 1,
      itemBuilder: (_, i) {
        if (i == slots.length) return _footer(list);
        return switch (slots[i]) {
          final String b => _bandHeader(b, bandCounts[b]!),
          final MangaEntry item => _row(item),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _row(MangaEntry item) {
    return _swipeable(
      item,
      ShelfRow(
        key: ValueKey(item.id),
        item: item,
        onEdit: () => _editEntry(item),
        onDelete: () => _delete(item),
        onMarkRead: () => _move(item, ShelfStatus.read),
        onReread: () => _reread(item),
        onMove: (status) => _move(item, status),
        onBump: (dir) => _bump(item, dir),
        onRate: (r) => state.setRating(item.id, r),
        onLongPress: () => _toggle(item.id),
        onToggleSelect: () => _toggle(item.id),
        selecting: _selecting,
        selected: _selected.contains(item.id),
      ),
    );
  }

  Widget _body() {
    if (state.loadFailed && state.entries.isEmpty) {
      return _message(
        icon: Icons.report_gmailerrorred_rounded,
        title: 'Your shelf could not be read',
        body: 'The saved data on this device is damaged, so nothing loaded. '
            'Import a backup to put your titles back.',
        actionLabel: 'Open settings',
        onAction: () => showSettingsSheet(context, state),
      );
    }
    if (state.entries.isEmpty) return _onboarding();
    final list = state.visible(_tab, _searchCtrl.text);
    if (list.isEmpty) return _emptyState();
    return SafeArea(top: false, child: _list(list));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final firstRun = state.entries.isEmpty && !state.loadFailed;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: t.ground,
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
        ),
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                if (!firstRun) _rail(),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
