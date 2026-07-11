import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/manga_entry.dart';
import '../theme.dart';
import '../widgets/manga_card.dart';
import 'edit_sheet.dart';
import 'settings_sheet.dart';
import 'stats_sheet.dart';

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
    (id: 'reading', label: 'Reading', icon: Icons.menu_book_rounded),
    (id: 'read', label: 'Read', icon: Icons.library_add_check_rounded),
    (id: 'dropped', label: 'Dropped', icon: Icons.block_rounded),
  ];

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

  Future<void> _addEntry() async {
    final entry = await showEditSheet(context);
    if (entry != null) await state.add(entry);
  }

  Future<void> _editEntry(MangaEntry item) async {
    final updated = await showEditSheet(context, initial: item);
    if (updated != null) await state.update(updated);
  }

  Future<void> _confirmDelete(MangaEntry item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.cardBorder)),
        title: Text('Delete "${item.title}"?',
            style: const TextStyle(color: AppColors.text, fontSize: 16)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppColors.textDim, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textFaint))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await state.remove(item.id);
  }

  Widget _emptyState() {
    final map = {
      'reading': (
        Icons.menu_book_rounded,
        'Nothing here yet!',
        'Tap + to start tracking your manga.'
      ),
      'read': (
        Icons.library_add_check_rounded,
        'No completed titles.',
        'Finish a manga to move it here.'
      ),
      'dropped': (
        Icons.block_rounded,
        'No dropped titles.',
        "Hopefully you won't need this tab!"
      ),
    };
    final (icon, title, body) = map[_tab]!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 68, color: AppColors.fieldBorder),
        const SizedBox(height: 20),
        Text(title,
            style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        const SizedBox(height: 6),
        Text(body,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: AppColors.textGhost, fontSize: 13)),
        ]),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      titleSpacing: 14,
      title: _searching
          ? TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search titles…',
                isDense: true,
                prefixIcon: Icon(Icons.search,
                    size: 16, color: AppColors.textFaint),
              ),
            )
          : Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.menu_book_rounded,
                    size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.text),
                  children: [
                    TextSpan(text: 'Manga '),
                    TextSpan(
                        text: 'Companion',
                        style: TextStyle(color: AppColors.accent)),
                  ],
                ),
              ),
            ]),
      actions: [
        IconButton(
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) _searchCtrl.clear();
          }),
          icon: Icon(_searching ? Icons.close : Icons.search,
              size: 20, color: AppColors.textDim),
        ),
        PopupMenuButton<SortMode>(
          icon: const Icon(Icons.sort, size: 20, color: AppColors.textDim),
          color: AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorder)),
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
                child: Row(children: [
                  SizedBox(
                    width: 22,
                    child: state.sortMode == mode
                        ? const Icon(Icons.check,
                            size: 15, color: AppColors.accent)
                        : null,
                  ),
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 13)),
                ]),
              ),
          ],
        ),
        IconButton(
          onPressed: () => showStatsSheet(context, state),
          icon: const Icon(Icons.bar_chart_rounded,
              size: 20, color: AppColors.textDim),
        ),
        IconButton(
          onPressed: () => showSettingsSheet(context, state),
          icon: const Icon(Icons.settings_outlined,
              size: 20, color: AppColors.textDim),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = state.visible(_tab, _searchCtrl.text);
    return Scaffold(
      appBar: _appBar(),
      body: list.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final item = list[i];
                return MangaCard(
                  key: ValueKey(item.id),
                  item: item,
                  onEdit: () => _editEntry(item),
                  onDelete: () => _confirmDelete(item),
                  onMarkRead: () => state.setStatus(item, 'read'),
                  onBump: (dir) => state.bumpChapter(item, dir),
                  onRate: (r) => state.setRating(item, r),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        backgroundColor: AppColors.accent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xF7121214),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              for (final t in _tabs)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _tab = t.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(t.icon,
                                  size: 22,
                                  color: _tab == t.id
                                      ? AppColors.accent
                                      : AppColors.textGhost),
                              if (state.countFor(t.id) > 0)
                                Positioned(
                                  top: -5,
                                  right: -10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _tab == t.id
                                          ? AppColors.accent
                                          : AppColors.field,
                                      borderRadius:
                                          BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      state.countFor(t.id) > 99
                                          ? '99+'
                                          : '${state.countFor(t.id)}',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: _tab == t.id
                                              ? Colors.white
                                              : AppColors.textFaint),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(t.label,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _tab == t.id
                                      ? AppColors.accent
                                      : AppColors.textGhost)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
