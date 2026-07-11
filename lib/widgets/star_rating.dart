import 'package:flutter/material.dart';

import '../theme.dart';

class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;
  const StarRating(
      {super.key, required this.value, this.onChanged, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        final filled = n <= value;
        return GestureDetector(
          // Tapping the current rating clears it, like the site.
          onTap: onChanged == null
              ? null
              : () => onChanged!(n == value ? 0 : n),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? AppColors.accentSoft : AppColors.fieldBorder,
            ),
          ),
        );
      }),
    );
  }
}
