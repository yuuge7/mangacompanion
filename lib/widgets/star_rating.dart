import 'package:flutter/material.dart';

import '../theme.dart';

/// Five stars, each its own 44x44 target so the control is usable without
/// precision. Tapping the current rating clears it, as it always has.
class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  const StarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Semantics(
      label: value == 0 ? 'Not rated' : 'Rated $value out of 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final n = i + 1;
          final filled = n <= value;
          return Semantics(
            button: onChanged != null,
            label: filled && n == value
                ? 'Clear rating'
                : 'Rate $n out of 5',
            excludeSemantics: true,
            child: InkResponse(
              radius: 22,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(n == value ? 0 : n),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  // Ratings are not reading position, so they stay ink.
                  color: filled ? t.ink : t.ruleStrong,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
