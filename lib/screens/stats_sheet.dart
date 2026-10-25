import 'package:flutter/material.dart';

import '../app_state.dart';
import '../format.dart';
import '../models/manga_entry.dart';
import '../stats.dart';
import '../theme.dart';
import '../widgets/sheet.dart';

Future<void> showStatsSheet(BuildContext context, AppState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StatsSheet(state: state),
  );
}

/// Read as a statement, not as a dashboard: label on the left, figure on the
/// right, every figure in tabular mono so the column aligns down the page.
class _StatsSheet extends StatelessWidget {
  final AppState state;
  const _StatsSheet({required this.state});

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    bool total = false,
  }) {
    final t = context.tk;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: (total ? Type.label : Type.bodySm)
                  .copyWith(color: total ? t.ink : t.inkMuted),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: total
                ? Type.number.copyWith(fontSize: 19, color: t.ink)
                : Type.numberSm.copyWith(fontSize: 15, color: t.ink),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final avg = state.averageRating;
    final rated = state.entries
        .where((e) => e.status == ShelfStatus.read && e.rating > 0)
        .length;
    final activity = readingStats(state.entries);

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SheetScaffold(
        title: 'Stats',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('By shelf'),
              const SizedBox(height: 4),
              for (final (i, s) in ShelfStatus.values.indexed) ...[
                if (i > 0) Divider(color: t.rule, height: 1),
                _line(context, s.label, '${state.countFor(s)}'),
              ],
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 1,
                color: t.ruleStrong,
              ),
              _line(context, 'Titles tracked', '${state.entries.length}',
                  total: true),
              const SizedBox(height: 22),
              const SectionLabel('Activity'),
              const SizedBox(height: 4),
              if (activity.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    'Log chapters with + or a swipe and your reading '
                    'week, month and streaks show up here.',
                    style: Type.bodySm.copyWith(color: t.inkFaint),
                  ),
                )
              else ...[
                _line(context, 'Chapters this week',
                    groupDigits(activity.thisWeek)),
                Divider(color: t.rule, height: 1),
                _line(context, 'Chapters this month',
                    groupDigits(activity.thisMonth)),
                Divider(color: t.rule, height: 1),
                _line(context, 'Chapters this year',
                    groupDigits(activity.thisYear)),
                Divider(color: t.rule, height: 1),
                _line(context, 'Finished this year',
                    titleCount(activity.finishedThisYear)),
                Divider(color: t.rule, height: 1),
                _line(context, 'Current streak',
                    dayCount(activity.currentStreak)),
                Divider(color: t.rule, height: 1),
                _line(context, 'Longest streak',
                    dayCount(activity.longestStreak)),
              ],
              const SizedBox(height: 22),
              const SectionLabel('All time'),
              const SizedBox(height: 4),
              _line(context, 'Chapters read',
                  groupDigits(state.totalChaptersRead)),
              Divider(color: t.rule, height: 1),
              _line(
                context,
                rated == 0 ? 'Average rating' : 'Average of $rated ratings',
                avg == 0 ? '—' : '${avg.toStringAsFixed(1)} / 5',
              ),
              if (state.entries.isEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Numbers fill in once you add a title.',
                  style: Type.bodySm.copyWith(color: t.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
