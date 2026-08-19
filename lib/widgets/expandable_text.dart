import 'package:flutter/material.dart';
import '../l10n/localization_context.dart';
import '../theme/app_theme.dart';

/// Long descriptions collapse to a fixed number of lines with a
/// "Voir plus"/"Voir moins" toggle, instead of dumping the full text.
class ExpandableText extends StatefulWidget {
  final String text;
  final int collapsedMaxLines;

  const ExpandableText({super.key, required this.text, this.collapsedMaxLines = 6});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  static const _style = TextStyle(fontSize: 14);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: _style),
        maxLines: widget.collapsedMaxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: _style,
            maxLines: _expanded ? null : widget.collapsedMaxLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (overflows)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _expanded ? context.tr('common.showLess') : context.tr('common.showMore'),
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      );
    });
  }
}
