import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../format.dart';
import '../models/manga_entry.dart';
import '../theme.dart';
import '../widgets/shelf_row.dart';
import 'edit_sheet.dart';
import 'settings_sheet.dart';
import 'stats_sheet.dart';

/// The shelf.
///
/// Three statuses are filters over one list, not destinations, so they sit
/// in a rail at the top rather than in a bottom bar — which also keeps the
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
  String _tab = 'reading';
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  AppState get state => widget.state;

  static const _tabs = [
    (id: 'reading', label: 'READING'),
    (id: 'read', label: 'READ'),
    (id: 'dropped', label: 'DROPPED'),
  ];

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

  void _onState() => setState(() {});

  // --------------------------------------------------------------- actions

  Future<void> _addEntry() async {
    final entry = await showEditSheet(context);
    if (entry != null) {
      await state.add(entry);
      if (mounted && entry.status != _tab) setState(() => _tab = entry.status);
    }
  }

  Future<void> _editEntry(MangaEntry item) async {
    final updated = await showEditSheet(context, initial: item);
    if (updated != null) await state.update(updated);
  }

  Future<void> _confirmDelete(MangaEntry item) async {
    final t = context.tk;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this title?'),
        content: Text(
          '${item.title} and its chapter count are removed from this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: t.danger,
              foregroundColor: t.onAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await state.remove(item.id);
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

  /// Status rail. Counts are the point, so they are set large in mono; the
  /// active filter is marked by an ink underline, never by the accent.
  Widget _rail() {
    final t = context.tk;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final tab in _tabs)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: _tab == tab.id,
                  label:
                      '${tab.label.toLowerCase()}, ${state.countFor(tab.id)} titles',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => _tab = tab.id),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _tab == tab.id ? t.ink : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Type.eyebrow.copyWith(
                              color: _tab == tab.id ? t.inkMuted : t.inkGhost,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${state.countFor(tab.id)}',
                            style: Type.number.copyWith(
                              fontSize: 20,
                              color: _tab == tab.id ? t.ink : t.inkGhost,
                            ),
                          ),
                          const SizedBox(height: 7),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            _sortControl(),
          ],
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
  bool get _banded => _tab == 'reading' && state.sortMode == SortMode.recent;

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

  Widget _emptyState() {
    if (_searchCtrl.text.trim().isNotEmpty) {
      return _message(
        icon: Icons.search_off_rounded,
        title: 'No matches here',
        body: 'Nothing on the ${_tab == 'read' ? 'read' : _tab} shelf matches '
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
      'read' => _message(
          icon: Icons.done_all_rounded,
          title: 'Nothing finished yet',
          body: 'Catch up to the last chapter of a title and it moves here, '
              'where you can rate it.',
        ),
      'dropped' => _message(
          icon: Icons.remove_circle_outline_rounded,
          title: 'Nothing dropped',
          body: 'Titles you give up on land here. They keep their chapter '
              'count in case you come back.',
        ),
      _ => _message(
          icon: Icons.bookmark_border_rounded,
          title: 'Your shelf is empty',
          body: 'Add a title with its cover, the site you read it on, and '
              'the chapter you are on.',
          actionLabel: 'Add a title',
          onAction: _addEntry,
        ),
    };
  }

  // ------------------------------------------------------------------ list

  Widget _list(List<MangaEntry> list) {
    // Rows, band headers and the closing tally, flattened into one list so
    // the whole shelf scrolls as a single column.
    final slots = <Widget>[];
    String? band;
    for (final item in list) {
      if (_banded) {
        final b = _bandFor(item.lastUpdated);
        if (b != band) {
          band = b;
          slots.add(_bandHeader(
              b, list.where((e) => _bandFor(e.lastUpdated) == b).length));
        }
      }
      slots.add(ShelfRow(
        key: ValueKey(item.id),
        item: item,
        onEdit: () => _editEntry(item),
        onDelete: () => _confirmDelete(item),
        onMarkRead: () => state.setStatus(item, 'read'),
        onMove: (status) => state.setStatus(item, status),
        onBump: (dir) => state.bumpChapter(item, dir),
        onRate: (r) => state.setRating(item, r),
      ));
    }
    slots.add(_footer(list));

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: slots.length,
      itemBuilder: (_, i) => slots[i],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final list = state.visible(_tab, _searchCtrl.text);

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
              _rail(),
              Expanded(
                child: state.loadFailed && state.entries.isEmpty
                    ? _message(
                        icon: Icons.report_gmailerrorred_rounded,
                        title: 'Your shelf could not be read',
                        body: 'The saved data on this device is damaged, so '
                            'nothing loaded. Import a backup to put your '
                            'titles back.',
                        actionLabel: 'Open settings',
                        onAction: () => showSettingsSheet(context, state),
                      )
                    : list.isEmpty
                        ? _emptyState()
                        : SafeArea(top: false, child: _list(list)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
