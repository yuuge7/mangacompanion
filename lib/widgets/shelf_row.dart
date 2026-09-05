import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models/manga_entry.dart';
import '../theme.dart';
import 'star_rating.dart';

/// One title on the shelf.
///
/// The row bleeds to both screen edges: the cover is a full-height *spine*
/// on the left, and the chapter stepper is a flush block on the right. What
/// separates rows is a hairline, not a gap — so scrolling reads as a
/// continuous shelf rather than a stack of cards.
class ShelfRow extends StatelessWidget {
  // Sized to a book: roughly 2:3 against [minHeight], so BoxFit.cover has
  // almost nothing to crop. Narrower than this and a cover is reduced to an
  // unreadable centre strip.
  static const spineWidth = 66.0;
  static const stepperWidth = 56.0;
  // 5:4 split of this leaves the smaller stepper block at 44dp.
  static const minHeight = 100.0;

  final MangaEntry item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkRead;
  final ValueChanged<String> onMove;
  final void Function(int dir) onBump;
  final ValueChanged<int> onRate;

  const ShelfRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkRead,
    required this.onMove,
    required this.onBump,
    required this.onRate,
  });

  Future<void> _openReadUrl(BuildContext context) async {
    final uri = Uri.tryParse(item.readUrl);
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || !uri.hasScheme) {
      messenger.showSnackBar(const SnackBar(
        content: Text('That read link is not a valid web address. Edit the '
            'title to fix it.'),
      ));
      return;
    }
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(const SnackBar(
        content: Text('No app on this phone can open that link.'),
      ));
    }
  }

  // ---------------------------------------------------------------- spine

  /// Titles with no cover still get a spine: a dye from the hand-picked set,
  /// with the title running down it the way it would on a real book.
  Widget _blankSpine(BuildContext context) {
    var hash = 0;
    for (final unit in item.title.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final dye = AppTokens.spineDyes[hash % AppTokens.spineDyes.length];
    // Every child is positioned, so the turned label reports no intrinsic
    // height. Otherwise a long title — rotated, its width becomes height —
    // stretches the whole row to the length of the title.
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: ColoredBox(color: dye)),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: RotatedBox(
              quarterTurns: 1,
              // Capped before rotation: turned sideways this width becomes
              // height, and an uncapped one would stretch the row to the
              // length of the title.
              child: SizedBox(
                width: minHeight - 24,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Type.title.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.4,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The cover, and nothing else. Reading position is stated as a number
  /// beside it, so marking it on the artwork as well only defaced the art.
  Widget _spine(BuildContext context) {
    final art = item.coverUrl.isEmpty
        ? _blankSpine(context)
        : CachedNetworkImage(
            imageUrl: item.coverUrl,
            fit: BoxFit.cover,
            fadeInDuration: Motion.of(context, Motion.state),
            // A cover this size leaves a conspicuous hole while it loads, so
            // fall back to the dyed spine in the meantime rather than a flat
            // block. Failure lands on the same thing.
            placeholder: (_, _) => _blankSpine(context),
            errorWidget: (_, _, _) => _blankSpine(context),
          );

    return Semantics(
      button: item.readUrl.isNotEmpty,
      label: item.readUrl.isEmpty
          ? 'Cover of ${item.title}'
          : 'Open ${item.title} where you read it',
      child: GestureDetector(
        onTap: item.readUrl.isEmpty ? null : () => _openReadUrl(context),
        child: SizedBox(width: spineWidth, child: art),
      ),
    );
  }

  // -------------------------------------------------------------- stepper

  Widget _stepperBlock(
    BuildContext context, {
    required int flex,
    required bool primary,
    required IconData icon,
    required double iconSize,
    required bool enabled,
    required String semanticLabel,
    required VoidCallback onTap,
    Color? tint,
    Border? border,
  }) {
    final t = context.tk;
    return Expanded(
      flex: flex,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        excludeSemantics: true,
        child: Material(
          color: enabled ? (primary ? t.raised : t.ground) : t.groundSunken,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: DecoratedBox(
              decoration: BoxDecoration(border: border),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: enabled ? (tint ?? t.ink) : t.inkGhost,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepper(BuildContext context) {
    final t = context.tk;
    final caughtUp = item.isDone;
    final canBack = item.currentChapter > 0;
    final next = item.currentChapter + 1;

    return SizedBox(
      width: stepperWidth,
      child: Column(
        children: [
          // Once you are caught up there is nothing to advance to, so the
          // primary block becomes the one thing left to do.
          if (caughtUp && item.status == 'reading')
            _stepperBlock(
              context,
              flex: 5,
              primary: true,
              icon: Icons.check_rounded,
              iconSize: 22,
              enabled: true,
              tint: t.done,
              semanticLabel: 'Move ${item.title} to read',
              onTap: onMarkRead,
              border: Border(left: BorderSide(color: t.rule)),
            )
          else
            _stepperBlock(
              context,
              flex: 5,
              primary: true,
              icon: Icons.add_rounded,
              iconSize: 22,
              enabled: !caughtUp,
              semanticLabel: 'Advance ${item.title} to chapter $next',
              onTap: () => onBump(1),
              border: Border(left: BorderSide(color: t.rule)),
            ),
          _stepperBlock(
            context,
            flex: 4,
            primary: false,
            icon: Icons.remove_rounded,
            iconSize: 16,
            enabled: canBack,
            tint: t.inkFaint,
            semanticLabel:
                'Go back to chapter ${item.currentChapter - 1} of ${item.title}',
            onTap: () => onBump(-1),
            border: Border(
              left: BorderSide(color: t.rule),
              top: BorderSide(color: t.rule),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- content

  Widget _title(BuildContext context) {
    final t = context.tk;
    final linked = item.readUrl.isNotEmpty;
    return Semantics(
      button: linked,
      label: linked ? 'Open ${item.title} where you read it' : null,
      child: GestureDetector(
        onTap: linked ? () => _openReadUrl(context) : null,
        behavior: HitTestBehavior.opaque,
        // Matches the height of the menu button beside it, so a one-line
        // title is still a full-size target. Costs no extra row height.
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: item.title,
              children: linked
                  ? [
                      const TextSpan(text: ' '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(Icons.north_east_rounded,
                            size: 13, color: t.inkFaint),
                      ),
                    ]
                  : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Type.title.copyWith(color: t.ink),
          ),
        ),
      ),
    );
  }

  Widget _position(BuildContext context) {
    final t = context.tk;
    final hasTotal = item.totalChapters != null && item.totalChapters! > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // The accent lives here and nowhere else: this is your place.
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.micro),
          switchInCurve: Motion.curve,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: Text(
            '${item.currentChapter}',
            key: ValueKey(item.currentChapter),
            style: Type.number.copyWith(color: t.accent),
          ),
        ),
        if (hasTotal)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Text('/ ${item.totalChapters}',
                style: Type.numberSm.copyWith(color: t.inkFaint)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Text('/ —',
                style: Type.numberSm.copyWith(color: t.inkGhost)),
          ),
      ],
    );
  }

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(R.badge),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(text, style: Type.eyebrow.copyWith(color: color)),
    );
  }

  Widget _overflow(BuildContext context) {
    final t = context.tk;
    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<String>(
        tooltip: 'More actions for ${item.title}',
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: t.inkFaint),
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
            default:
              onMove(value);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', height: 44, child: Text('Edit')),
          for (final (id, label) in const [
            ('reading', 'Move to reading'),
            ('read', 'Move to read'),
            ('dropped', 'Move to dropped'),
          ])
            if (item.status != id)
              PopupMenuItem(value: id, height: 44, child: Text(label)),
          PopupMenuItem(
            value: 'delete',
            height: 44,
            child: Text('Delete', style: TextStyle(color: t.danger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final caughtUp = item.isDone;
    final rated = item.status == 'read';
    final stale = item.status == 'reading' ? timeAgo(item.lastUpdated) : '';

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.rule)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        // The spine and the stepper both need to fill whatever height the
        // content ends up needing, and a list gives us no height to stretch
        // into — so the row measures itself.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _spine(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 4, 11),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _title(context)),
                          _overflow(context),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Figures on the baseline, age at the right margin —
                      // the Wrap absorbs a large text scale without
                      // pushing the timestamp off the row.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _position(context),
                                if (caughtUp && !rated)
                                  _badge(context, 'CAUGHT UP', t.done),
                                if (rated)
                                  StarRating(
                                      value: item.rating, onChanged: onRate),
                              ],
                            ),
                          ),
                          if (stale.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(stale,
                                  style:
                                      Type.meta.copyWith(color: t.inkGhost)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!rated) _stepper(context),
            ],
          ),
        ),
      ),
    );
  }
}
