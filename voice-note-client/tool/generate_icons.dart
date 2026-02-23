// One-off script to generate app_icon.png and splash logo.png per design-system.
// Run from voice-note-client: dart run tool/generate_icons.dart
// Requires: dependency image in pubspec.yaml

import 'dart:io';

import 'package:image/image.dart' as img;

void main() async {
  final baseDir = Directory.current.path;
  if (!baseDir.endsWith('voice-note-client')) {
    print('Run from voice-note-client: dart run tool/generate_icons.dart');
    exit(1);
  }

  final iconPath = '$baseDir/assets/icon/app_icon.png';
  final splashPath = '$baseDir/assets/splash/logo.png';

  final brandBlue = img.ColorUint8.rgba(22, 119, 255, 255);
  final white = img.ColorUint8.rgb(255, 255, 255);

  // App icon: 1024x1024, white background, brand mark
  final iconImg = img.Image(width: 1024, height: 1024, numChannels: 3);
  img.fill(iconImg, color: white);
  _drawMark(iconImg, 1024, brandBlue, null, 0.18, 0.82);

  await File(iconPath).writeAsBytes(img.encodePng(iconImg));
  print('Wrote $iconPath');

  // Splash logo: 864x864. Use RGB + white background for broad codec support (iOS/Android).
  final splashImg = img.Image(width: 864, height: 864, numChannels: 3);
  img.fill(splashImg, color: white);
  _drawMark(splashImg, 864, img.ColorUint8.rgb(22, 119, 255), null, 0.18, 0.82);

  await File(splashPath).writeAsBytes(img.encodePng(splashImg));
  print('Wrote $splashPath');
}

/// Draws the mark: check + three horizontal ledger lines. [size] is canvas size.
/// [padding] = fraction of size for margin; [inner] = fraction for content box.
/// If [bg] is null, only draw the mark (caller must have filled background).
void _drawMark(
  img.Image image,
  int size,
  img.ColorUint8 color,
  img.ColorUint8? bg,
  double padding,
  double inner,
) {
  final w = (size * inner).round();
  final left = (size - w) ~/ 2;
  final top = (size - w) ~/ 2;
  final right = left + w;
  final bottom = top + w;
  final thick = (size * 0.055).round().clamp(4, 32);
  final lineGap = (size * 0.12).round();

  // Checkmark: two segments (left-bottom to center, center to right-top)
  final cx = (left + right) ~/ 2;
  final cy = (top + bottom) ~/ 2;
  final x1 = (left + 0.15 * w).round();
  final y1 = (bottom - 0.2 * w).round();
  final x2 = (right - 0.25 * w).round();
  final y2 = (top + 0.35 * w).round();
  img.drawLine(
    image,
    x1: x1,
    y1: y1,
    x2: cx,
    y2: cy,
    color: color,
    thickness: thick,
    antialias: true,
  );
  img.drawLine(
    image,
    x1: cx,
    y1: cy,
    x2: x2,
    y2: y2,
    color: color,
    thickness: thick,
    antialias: true,
  );

  // Three horizontal ledger lines below the check (short, not extending into tagline area)
  final lineY0 = (bottom - lineGap).round();
  final lineW = (w * 0.5).round();
  final lineX0 = (size - lineW) ~/ 2;
  final lineThick = (size * 0.028).round().clamp(2, 16);
  for (var i = 0; i < 3; i++) {
    final y = lineY0 + i * lineGap;
    img.drawLine(
      image,
      x1: lineX0,
      y1: y,
      x2: lineX0 + lineW,
      y2: y,
      color: color,
      thickness: lineThick,
      antialias: true,
    );
  }
}
