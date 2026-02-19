import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/core/di/database_provider.dart';
import 'package:suikouji/core/di/network_providers.dart';
import 'package:suikouji/core/network/api_client.dart';
import 'package:suikouji/core/network/api_config.dart';
import 'package:suikouji/features/voice/domain/draft_batch.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';
import 'package:suikouji/features/voice/domain/voice_state.dart';
import 'package:suikouji/features/voice/presentation/providers/voice_session_provider.dart';
import 'package:suikouji/features/voice/presentation/providers/voice_settings_provider.dart';
import 'package:suikouji/features/voice/presentation/widgets/mode_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final apiClient = ApiClient(ApiConfig(prefs));
    db = AppDatabase(NativeDatabase.memory());

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(apiClient),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );

    // Use keyboard mode so startSession() skips hardware initialization
    container
        .read(voiceSettingsProvider.notifier)
        .setInputMode(VoiceInputMode.keyboard);
  });

  tearDown(() async {
    await container.read(voiceSessionProvider.notifier).endSession();
    container.dispose();
    await db.close();
  });

  group('VoiceSessionNotifier', () {
    test('initial state is idle with empty messages', () {
      final state = container.read(voiceSessionProvider);

      expect(state.voiceState, VoiceState.idle);
      expect(state.interimText, '');
      expect(state.parseResult, isNull);
      expect(state.messages, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('startSession transitions to listening and adds assistant message',
        () async {
      await container.read(voiceSessionProvider.notifier).startSession();
      final state = container.read(voiceSessionProvider);

      expect(state.voiceState, VoiceState.listening);
      expect(state.messages, hasLength(1));
      expect(state.messages.first.isUser, isFalse);
      expect(state.messages.first.text, contains('听'));
    });

    test('onSpeechDetected transitions to recognizing', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.recognizing);
    });

    test('onInterimText updates interim text', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onInterimText('咖啡');

      expect(container.read(voiceSessionProvider).interimText, '咖啡');
    });

    test('onFinalText transitions to confirming with parse result', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onFinalText(
        '咖啡28块',
        DraftBatch.fromResults(const [
          ParseResult(amount: 28.0, category: '餐饮', source: ParseSource.local),
        ]),
      );

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.confirming);
      expect(state.parseResult?.amount, 28.0);
      expect(state.interimText, '');
      expect(state.messages, hasLength(2));
      expect(state.messages.last.isUser, isTrue);
      expect(state.messages.last.text, '咖啡28块');
    });

    test('confirmTransaction returns to listening and clears parse result',
        () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onFinalText(
        '咖啡28块',
        DraftBatch.fromResults(const [
          ParseResult(amount: 28.0, category: '餐饮', source: ParseSource.local),
        ]),
      );
      await notifier.confirmTransaction();

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.listening);
      expect(state.parseResult, isNull);
      expect(state.messages, hasLength(3));
      expect(state.messages.last.text, contains('记录'));
    });

    test('cancelTransaction returns to listening', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onFinalText(
        '咖啡28块',
        DraftBatch.fromResults(const [
          ParseResult(amount: 28.0, category: '餐饮', source: ParseSource.local),
        ]),
      );
      notifier.cancelTransaction();

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.listening);
      expect(state.parseResult, isNull);
      expect(state.messages.last.text, contains('取消'));
    });

    test('endSession resets to initial state', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      await notifier.endSession();

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.idle);
      expect(state.messages, isEmpty);
    });

    test('onError adds assistant message and returns to listening', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onError('网络连接失败');

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.listening);
      expect(state.errorMessage, '网络连接失败');
      expect(state.messages.last.text, contains('网络连接失败'));
    });

    test('onParseResultUpdated modifies existing result', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onFinalText(
        '咖啡28块',
        DraftBatch.fromResults(const [
          ParseResult(amount: 28.0, category: '餐饮', source: ParseSource.local),
        ]),
      );

      final updated =
          container.read(voiceSessionProvider).parseResult!.copyWith(
                amount: 35.0,
              );
      notifier.onParseResultUpdated(updated);

      expect(
          container.read(voiceSessionProvider).parseResult?.amount, 35.0);
    });

    test('onError adds error message and returns to listening', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onError('ASR connection failed');

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.listening);
      expect(state.errorMessage, 'ASR connection failed');
      expect(state.messages.last.text, contains('ASR connection failed'));
    });

    test('delegate methods ignored after endSession', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      await notifier.endSession();

      // These should all be no-ops
      notifier.onSpeechDetected();
      notifier.onInterimText('test');
      notifier.onError('late error');

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.idle);
      expect(state.messages, isEmpty);
    });

    test('onConfirmTransaction only updates state without saving', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onFinalText(
        '咖啡28块',
        DraftBatch.fromResults(const [
          ParseResult(amount: 28.0, category: '餐饮', source: ParseSource.local),
        ]),
      );

      // Simulate orchestrator's _checkAutoSubmit calling onConfirmTransaction
      notifier.onConfirmTransaction();

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.listening);
      expect(state.parseResult, isNull);
      // Should NOT add a "已记录" message (no save happened)
      expect(
        state.messages.where((m) => m.text.contains('记录')),
        isEmpty,
      );
    });

    // pushStart auto-restart is tested implicitly via submitTextInput below.
    // pushStart() requires native AudioRecorder plugin, not available in unit tests.

    test('submitTextInput auto-restarts session after timeout', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      await notifier.endSession();

      await notifier.submitTextInput('咖啡28块');

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, isNot(VoiceState.idle));
    });

    test('confirmTransaction handles save error gracefully', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      await notifier.startSession();
      notifier.onSpeechDetected();
      notifier.onFinalText(
        '测试',
        DraftBatch.fromResults(const [
          ParseResult(amount: -1, category: '餐饮', source: ParseSource.local),
        ]),
      );

      await notifier.confirmTransaction();

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.listening);
      expect(state.messages.last.text, contains('保存失败'));
    });
  });
}
