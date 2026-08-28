import 'package:flutter/material.dart';

/// A stable glyph viewport across explanation and pronunciation, including
/// vowel marks and dots. It does not shrink when the example appears.
Size lessonLetterDisplaySize(BuildContext context) {
  final height = (MediaQuery.sizeOf(context).height * .28).clamp(80.0, 160.0);
  return Size(height * 1.25, height);
}
