import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/manga_entry.dart';
import '../theme.dart';
import 'star_rating.dart';

String timeAgo(int ts) {
  if (ts == 0) return '';
  final d = DateTime.now().millisecondsSinceEpoch - ts;
  final m = d ~/ 60000, h = d ~/ 3600000, day = d ~/ 86400000;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  if (h < 24) return '${h}h ago';
  return '${day}d ago';
}

class MangaCard extends StatelessWidget {
  final MangaEntry item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkRead;
  final void Function(int dir) onBump;
  final ValueChanged<int> onRate;

  const MangaCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkRead,
    required this.onBump,
    required this.onRate,
  });

  Future<void> _openReadUrl(BuildContext context) async {
    final uri = Uri.tryParse(item.readUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the read link')));
    }
  }

  Widget _cover() {
    final placeholder = Container(
      width: 56,
      height: 78,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.menu_book_rounded,
          size: 20, color: AppColors.textGhost),
    );
    final img = item.coverUrl.isEmpty
        ? placeholder
        : ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: item.coverUrl,
              width: 56,
              height: 78,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
          );
    return Stack(
      children: [
        img,
        if (item.totalChapters != null && item.totalChapters! > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 3,
                backgroundColor: AppColors.field,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ),
      ],
    );
  }

  Widget _bumpButton(IconData icon, int dir) {
    final disabled = (dir > 0 && item.isDone) ||
        (dir < 0 && item.currentChapter <= 0);
    return Material(
      color: disabled ? const Color(0xFF1C1C1E) : AppColors.field,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: disabled ? null : () => onBump(dir),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon,
              size: 16,
              color: disabled ? AppColors.fieldBorder : AppColors.textDim),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = item.isDone;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cover(),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: item.readUrl.isEmpty
                            ? null
                            : () => _openReadUrl(context),
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.readUrl.isEmpty
                                ? AppColors.text
                                : AppColors.accentSoft,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined,
                          size: 16, color: AppColors.textGhost),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: AppColors.textGhost),
                    ),
                  ],
                ),
                if (item.status == 'reading' && item.lastUpdated > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      const Icon(Icons.schedule,
                          size: 10, color: AppColors.textGhost),
                      const SizedBox(width: 3),
                      Text(timeAgo(item.lastUpdated),
                          style: const TextStyle(
                              color: AppColors.textGhost, fontSize: 11)),
                    ]),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${item.currentChapter}',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    if (item.totalChapters != null &&
                        item.totalChapters! > 0) ...[
                      const Text(' / ',
                          style: TextStyle(
                              color: AppColors.fieldBorder, fontSize: 13)),
                      Text('${item.totalChapters}',
                          style: const TextStyle(
                              color: AppColors.textFaint, fontSize: 13)),
                    ],
                    if (done)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Done!',
                            style: TextStyle(
                                color: AppColors.accentSoft,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    const Spacer(),
                    if (item.status == 'read')
                      StarRating(value: item.rating, onChanged: onRate)
                    else ...[
                      if (done && item.status == 'reading')
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Material(
                            color: AppColors.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(9),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: onMarkRead,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 9),
                                child: Text('✓ Mark Read',
                                    style: TextStyle(
                                        color: AppColors.accentSoft,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      _bumpButton(Icons.remove, -1),
                      const SizedBox(width: 5),
                      _bumpButton(Icons.add, 1),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
