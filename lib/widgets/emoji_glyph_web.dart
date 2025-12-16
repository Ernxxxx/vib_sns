import 'dart:ui';

import 'package:flutter/widgets.dart';

Widget buildEmojiGlyph({
  required String emoji,
  required double size,
  required TextStyle style,
}) {
  final assetPath = _emojiAssetPath(emoji);
  if (assetPath == null) {
    return Text(emoji, style: style);
  }

  final provider = AssetImage(assetPath);
  final imageWidget = Image(
    image: provider,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
  );

  final shadows = style.shadows ?? const <Shadow>[];
  if (shadows.isEmpty) {
    return imageWidget;
  }

  return SizedBox.square(
    dimension: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (final shadow in shadows)
          Transform.translate(
            offset: shadow.offset,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: shadow.blurRadius,
                sigmaY: shadow.blurRadius,
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(shadow.color, BlendMode.srcIn),
                child: Image(
                  image: provider,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        imageWidget,
      ],
    ),
  );
}

String? _emojiAssetPath(String emoji) {
  switch (emoji) {
    case '🌸':
      return 'assets/emoji/noto/emoji_u1f338.png';
    case '🌱':
      return 'assets/emoji/noto/emoji_u1f331.png';
    default:
      return null;
  }
}
