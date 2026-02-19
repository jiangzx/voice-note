import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/core/di/database_provider.dart';
import 'package:suikouji/core/di/network_providers.dart';
import 'package:suikouji/core/network/api_client.dart';
import 'package:suikouji/core/network/api_config.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';
import 'package:suikouji/features/voice/domain/voice_state.dart';
import 'package:suikouji/features/voice/presentation/providers/voice_session_provider.dart';
import 'package:suikouji/features/voice/presentation/providers/voice_settings_provider.dart';
import 'package:suikouji/features/voice/presentation/widgets/mode_switcher.dart';

/// End-to-end test: Text input → Local NLP → Confirm → SQLite persistence.
///
/// This test validates the complete voice-note pipeline using keyboard mode
/// (no hardware dependencies) and an in-memory database.
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

    // Use keyboard mode to bypass hardware
    container
        .read(voiceSettingsProvider.notifier)
        .setInputMode(VoiceInputMode.keyboard);
  });

  tearDown(() async {
    await container.read(voiceSessionProvider.notifier).endSession();
    container.dispose();
    await db.close();
  });

  group('E2E: text → NLP → DB', () {
    test('complete flow: input → parse → confirm → persisted to SQLite',
        () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      final txDao = TransactionDao(db);

      // 1. Start session
      await notifier.startSession();
      expect(
        container.read(voiceSessionProvider).voiceState,
        VoiceState.listening,
      );

      // 2. Submit text input — local NLP should parse "午饭35" as
      //    amount=35, category=餐饮
      await notifier.submitTextInput('午饭35');

      // Allow async processing to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stateAfterParse = container.read(voiceSessionProvider);
      expect(stateAfterParse.voiceState, VoiceState.confirming);
      expect(stateAfterParse.parseResult, isNotNull);
      expect(stateAfterParse.parseResult!.amount, 35.0);
      expect(stateAfterParse.parseResult!.category, '餐饮');
      expect(stateAfterParse.parseResult!.source, ParseSource.local);

      // 3. Confirm the transaction — should save to DB
      await notifier.confirmTransaction();

      final stateAfterConfirm = container.read(voiceSessionProvider);
      expect(stateAfterConfirm.voiceState, VoiceState.listening);
      expect(stateAfterConfirm.parseResult, isNull);

      // 4. Verify persisted in database
      final rows = await txDao.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.amount, 35.0);
      expect(rows.first.description, isNotNull);

      // 5. Chat messages should contain confirmation
      final messages = stateAfterConfirm.messages;
      expect(messages.any((m) => m.text.contains('记录')), isTrue);
    });

    test('multiple transactions in sequence', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      final txDao = TransactionDao(db);

      await notifier.startSession();

      // Transaction 1: 午饭35
      await notifier.submitTextInput('午饭35');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await notifier.confirmTransaction();

      // Transaction 2: 打车28块5
      await notifier.submitTextInput('打车28块5');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await notifier.confirmTransaction();

      // Verify both saved
      final rows = await txDao.getAll();
      expect(rows, hasLength(2));

      final amounts = rows.map((r) => r.amount).toSet();
      expect(amounts, containsAll([35.0, 28.5]));
    });

    test('cancel does not persist to database', () async {
      final notifier = container.read(voiceSessionProvider.notifier);
      final txDao = TransactionDao(db);

      await notifier.startSession();
      await notifier.submitTextInput('咖啡15');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        container.read(voiceSessionProvider).voiceState,
        VoiceState.confirming,
      );

      // Cancel instead of confirm
      notifier.cancelTransaction();

      expect(
        container.read(voiceSessionProvider).voiceState,
        VoiceState.listening,
      );

      // Verify nothing persisted
      final rows = await txDao.getAll();
      expect(rows, isEmpty);
    });

    test('incomplete parse still transitions to confirming', () async {
      final notifier = container.read(voiceSessionProvider.notifier);

      await notifier.startSession();

      // "花了100" — local NLP finds amount but no category → incomplete parse
      // NLP orchestrator tries LLM (fails in test) → returns local result
      await notifier.submitTextInput('花了100');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final state = container.read(voiceSessionProvider);
      expect(state.voiceState, VoiceState.confirming);
      expect(state.parseResult?.amount, 100.0);
    });
  });
}
