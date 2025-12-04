import 'dart:io';

import 'package:image/image.dart' as img;

/// Generates launcher icon assets with consistent padding so the home screen
/// icon does not appear over-zoomed.
Future<void> main() async {
  const sourcePath = 'assets/app_logo.png';
  const foregroundSize = 432; // Recommended adaptive icon asset size (xxxhdpi)
  const designScale = 0.10; // Max padding to make the symbol ultra tiny

  final source = img.decodeImage(await File(sourcePath).readAsBytes())!;
  final cropped = _cropToContent(source);

  final foreground =
      _renderSymbol(cropped, size: foregroundSize, scale: designScale);
  File('android/app/src/main/res/drawable/ic_launcher_symbol.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(foreground));

  const legacyBaseSize = 48; // mdpi
  const densities = <String, double>{
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  final yellow = img.ColorRgba8(255, 255, 0, 255);
  densities.forEach((name, factor) {
    final size = (legacyBaseSize * factor).round();
    final icon = _renderLegacyIcon(
      cropped,
      size: size,
      scale: designScale,
      background: yellow,
    );
    final legacyPath =
        'android/app/src/main/res/mipmap-$name/ic_launcher_custom.png';
    File(legacyPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(icon));

    final defaultPath =
        'android/app/src/main/res/mipmap-$name/ic_launcher.png';
    File(defaultPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(icon));
  });
}

img.Image _cropToContent(img.Image src) {
  var minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final a = (src.getPixel(x, y) as img.Pixel).a.toInt();
      if (a == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX == -1) return src;
  return img.copyCrop(
    src,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}

img.Image _renderSymbol(
  img.Image source, {
  required int size,
  required double scale,
}) {
  final longest = (size * scale).round();
  final ratio = longest / [source.width, source.height].reduce((a, b) => a > b ? a : b);
  final resized = img.copyResize(
    source,
    width: (source.width * ratio).round(),
    height: (source.height * ratio).round(),
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  final dx = ((size - resized.width) / 2).round();
  final dy = ((size - resized.height) / 2).round();
  img.compositeImage(
    canvas,
    resized,
    dstX: dx,
    dstY: dy,
    blend: img.BlendMode.direct,
  );
  return canvas;
}

img.Image _renderLegacyIcon(
  img.Image source, {
  required int size,
  required double scale,
  required img.Color background,
}) {
  final icon = img.Image(width: size, height: size, numChannels: 4);
  img.fill(icon, color: background);

  final longest = (size * scale).round();
  final ratio = longest / [source.width, source.height].reduce((a, b) => a > b ? a : b);
  final resized = img.copyResize(
    source,
    width: (source.width * ratio).round(),
    height: (source.height * ratio).round(),
    interpolation: img.Interpolation.cubic,
  );
  final dx = ((size - resized.width) / 2).round();
  final dy = ((size - resized.height) / 2).round();
  img.compositeImage(
    icon,
    resized,
    dstX: dx,
    dstY: dy,
    blend: img.BlendMode.alpha,
  );

  return icon;
}
