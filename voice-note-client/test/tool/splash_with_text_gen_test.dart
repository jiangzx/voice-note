// Generates assets/splash/logo.png with mark + "AI 懂你说的，记账更轻松".
// Run from voice-note-client: flutter test test/tool/splash_with_text_gen_test.dart --update-goldens
// Then: cp test/tool/goldens/splash_logo.png assets/splash/logo.png

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _brandBlue = Color(0xFF1677FF);
const _textColor = Color(0xFF4E5969);
const _width = 864;
const _height = 1024;

const _taglineStyle = TextStyle(
  fontSize: 22,
  fontWeight: FontWeight.w500,
  color: _textColor,
  height: 1.3,
);

final _splashKey = UniqueKey();

void main() {
  testWidgets('generate splash with tagline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: _splashKey,
          child: Container(
            width: _width.toDouble(),
            height: _height.toDouble(),
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 80),
                SizedBox(
                  width: 400,
                  height: 400,
                  child: CustomPaint(painter: _MarkOnlyPainter()),
                ),
                const SizedBox(height: 48),
                const Text('AI 懂你说的，记账更轻松', style: _taglineStyle, textAlign: TextAlign.center),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_splashKey),
    );
    final image = await boundary!.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final path = 'assets/splash/logo.png';
    await File(path).writeAsBytes(pngBytes);
    debugPrint('Wrote $path (${_width}x$_height)');
  });
}

class _MarkOnlyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.82;
    final left = (size.width - w) / 2;
    final top = (size.height - w) / 2;
    final right = left + w;
    final bottom = top + w;
    final thick = (size.width * 0.055).clamp(4.0, 32.0).toDouble();
    final lineGap = size.width * 0.12;

    final paint = Paint()
      ..color = _brandBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = thick
      ..strokeCap = StrokeCap.round;

    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;
    final x1 = left + 0.15 * w;
    final y1 = bottom - 0.2 * w;
    final x2 = right - 0.25 * w;
    final y2 = top + 0.35 * w;

    canvas.drawLine(Offset(x1, y1), Offset(cx, cy), paint);
    canvas.drawLine(Offset(cx, cy), Offset(x2, y2), paint);

    final lineY0 = bottom - lineGap;
    final lineW = w * 0.7;
    final lineX0 = (size.width - lineW) / 2;
    final lineThick = (size.width * 0.028).clamp(2.0, 16.0).toDouble();
    paint.strokeWidth = lineThick;
    for (var i = 0; i < 3; i++) {
      final y = lineY0 + i * lineGap;
      canvas.drawLine(
        Offset(lineX0, y),
        Offset(lineX0 + lineW, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SplashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Transparent – native splash uses white background
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
