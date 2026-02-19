import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/domain/voice_state.dart';
import 'package:suikouji/features/voice/presentation/widgets/voice_animation.dart';

void main() {
  Widget buildWidget(VoiceState state, {double size = 120}) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: Scaffold(body: Center(child: VoiceAnimationWidget(state: state, size: size))),
    );
  }

  group('VoiceAnimationWidget', () {
    testWidgets('renders idle state with mic icon', (tester) async {
      await tester.pumpWidget(buildWidget(VoiceState.idle));

      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('renders listening state with mic icon', (tester) async {
      await tester.pumpWidget(buildWidget(VoiceState.listening));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('renders recognizing state with mic icon and custom paint', (tester) async {
      await tester.pumpWidget(buildWidget(VoiceState.recognizing));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders confirming state with check icon', (tester) async {
      await tester.pumpWidget(buildWidget(VoiceState.confirming));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('transitions between states via AnimatedSwitcher', (tester) async {
      await tester.pumpWidget(buildWidget(VoiceState.idle));
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      await tester.pumpWidget(buildWidget(VoiceState.listening));
      // Use pump (not pumpAndSettle) because listening animation repeats forever
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(buildWidget(VoiceState.idle, size: 200));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, 200);
      expect(sizedBox.height, 200);
    });
  });
}
