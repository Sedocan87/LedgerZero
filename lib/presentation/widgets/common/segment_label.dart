import 'package:flutter/material.dart';

/// The label of a [ButtonSegment]: always one line. When the segments share
/// a narrow width ("Wöchentlich", "Monatlich" in four segments on a 360 dp
/// phone) the label scales down a little instead of breaking mid-word.
class SegmentLabel extends StatelessWidget {
  const SegmentLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, softWrap: false),
    );
  }
}
