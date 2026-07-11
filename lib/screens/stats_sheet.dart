import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

Future<void> showStatsSheet(BuildContext context, AppState state) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _StatsSheet(state: state),
  );
}

class _StatsSheet extends StatelessWidget {
  final AppState state;
  const _StatsSheet({required this.state});

  Widget _tile(String label, String value, {Color color = AppColors.text}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textFaint, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reading = state.countFor('reading');
    final read = state.countFor('read');
    final dropped = state.countFor('dropped');
    final avg = state.averageRating;
    return Padding(
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
          const Text('Your Stats',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(children: [
            _tile('Reading', '$reading', color: AppColors.accent),
            const SizedBox(width: 10),
            _tile('Completed', '$read', color: AppColors.success),
            const SizedBox(width: 10),
            _tile('Dropped', '$dropped', color: AppColors.danger),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _tile('Chapters read', '${state.totalChaptersRead}',
                color: AppColors.accentSoft),
            const SizedBox(width: 10),
            _tile('Avg. rating',
                avg == 0 ? '—' : '${avg.toStringAsFixed(1)} ★',
                color: AppColors.accentSoft),
          ]),
        ],
      ),
    );
  }
}
