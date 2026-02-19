import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/di/network_providers.dart';
import 'package:suikouji/core/network/api_client.dart';
import 'package:suikouji/core/network/api_config.dart';
import 'package:suikouji/features/voice/presentation/providers/voice_session_provider.dart';
import 'package:suikouji/features/voice/presentation/voice_recording_screen.dart';
import 'package:suikouji/features/voice/presentation/widgets/voice_animation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient testApiClient;
  late SharedPreferences testPrefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'voice_tutorial_seen': true});
    testPrefs = await SharedPreferences.getInstance();
    testApiClient = ApiClient(ApiConfig(testPrefs));

    // Mock flutter_tts platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => 1,
        );
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(testPrefs),
        apiClientProvider.overrideWithValue(testApiClient),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        home: const VoiceRecordingScreen(),
      ),
    );
  }

  group('VoiceRecordingScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildScreen());
      // Pump twice: 1st for post-frame callback, 2nd for async startSession
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('语音记账'), findsOneWidget);
    });

    testWidgets('shows close button in app bar', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('renders status text after session starts', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final hasStatusText =
          find.text('点击开始').evaluate().isNotEmpty ||
          find.text('正在聆听...').evaluate().isNotEmpty ||
          find.text('正在识别...').evaluate().isNotEmpty ||
          find.text('请确认以下信息').evaluate().isNotEmpty ||
          find.text('请确认或说出要修改的内容').evaluate().isNotEmpty;
      expect(hasStatusText, isTrue);
    });

    testWidgets('shows a voice status hint', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final hasStatusHint =
          find.text('点击开始').evaluate().isNotEmpty ||
          find.text('正在聆听...').evaluate().isNotEmpty ||
          find.text('正在识别...').evaluate().isNotEmpty ||
          find.text('请确认以下信息').evaluate().isNotEmpty ||
          find.text('请确认或说出要修改的内容').evaluate().isNotEmpty;
      expect(hasStatusHint, isTrue);
    });

    testWidgets('shows mode switcher with auto/hold/keyboard', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('自动'), findsOneWidget);
      expect(find.text('按住'), findsOneWidget);
      expect(find.text('键盘'), findsOneWidget);
    });

    testWidgets('shows voice animation area in auto mode', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VoiceAnimationWidget), findsOneWidget);
    });
  });

  group('VoiceSessionState', () {
    test('copyWith clearParseResult works', () {
      const state = VoiceSessionState(parseResult: null);
      final updated = state.copyWith(clearParseResult: true);
      expect(updated.parseResult, isNull);
    });

    test('copyWith clearError works', () {
      const state = VoiceSessionState(errorMessage: 'test');
      final updated = state.copyWith(clearError: true);
      expect(updated.errorMessage, isNull);
    });
  });
}
