import 'package:flutter/widgets.dart';

Widget buildEmojiGlyph({
  required String emoji,
  required double size,
  required TextStyle style,
}) {
  return Text(emoji, style: style);
}

