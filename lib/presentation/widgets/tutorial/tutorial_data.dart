import 'package:flutter/material.dart';

enum TutorialPosition { top, bottom, left, right, auto }

class TutorialStep {
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final TutorialPosition position;

  TutorialStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.position = TutorialPosition.auto,
  });
}
