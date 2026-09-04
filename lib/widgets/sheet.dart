import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared chrome for the three bottom sheets: a ruled title bar with a real
/// 44px close target, then content. No drag pill, no elevation tint — the
/// rule does the separating.
class SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const SheetScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.rule)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.display.copyWith(color: t.ink)),
                  ),
                  InkResponse(
                    radius: 24,
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Semantics(
                        button: true,
                        label: 'Close',
                        child: Icon(Icons.close_rounded,
                            size: 20, color: t.inkMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// A small caps section marker. Used to break sheets into parts without
/// adding boxes.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: Type.eyebrow.copyWith(color: context.tk.inkFaint));
  }
}

/// The form field label, sitting on the same ruled baseline as its input.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SectionLabel(text),
    );
  }
}
