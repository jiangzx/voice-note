import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/network/api_client.dart';
import 'package:suikouji/core/network/api_config.dart';
import 'package:suikouji/core/network/dto/transaction_correction_request.dart';
import 'package:suikouji/core/network/dto/transaction_correction_response.dart';
import 'package:suikouji/core/network/network_status_service.dart';
import 'package:suikouji/features/voice/data/llm_repository.dart';
import 'package:suikouji/features/voice/data/local_nlp_engine.dart';
import 'package:suikouji/features/voice/domain/draft_batch.dart';
import 'package:suikouji/features/voice/domain/nlp_orchestrator.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalNlpEngine localEngine;
  late _FakeLlmRepository fakeLlmRepo;
  late _FakeNetworkStatus fakeNetwork;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    localEngine = LocalNlpEngine();
    fakeLlmRepo = _FakeLlmRepository(ApiClient(ApiConfig(prefs)));
    fakeNetwork = _FakeNetworkStatus();
  });

  NlpOrchestrator createOrchestrator() => NlpOrchestrator(
    localEngine: localEngine,
    llmRepository: fakeLlmRepo,
    networkStatus: fakeNetwork,
  );

  group('parse', () {
    test(
      'online parse prefers LLM even when local parse is complete',
      () async {
        fakeNetwork.online = true;
        fakeLlmRepo.nextParseResults = const [
          ParseResult(
            amount: 35,
            category: '餐饮',
            description: '午饭',
            type: 'EXPENSE',
            confidence: 0.95,
            source: ParseSource.llm,
          ),
        ];
        final orchestrator = createOrchestrator();

        final results = await orchestrator.parse('午饭35');

        expect(results, hasLength(1));
        expect(results[0].source, ParseSource.llm);
        expect(results[0].amount, 35.0);
        expect(results[0].category, '餐饮');
        expect(results[0].confidence, 0.95);
      },
    );

    test('returns batch results from LLM when local is incomplete', () async {
      fakeNetwork.online = true;
      fakeLlmRepo.nextParseResults = [
        const ParseResult(
          amount: 60,
          category: '餐饮',
          description: '吃饭',
          type: 'EXPENSE',
          confidence: 0.95,
          source: ParseSource.llm,
        ),
        const ParseResult(
          amount: 30,
          category: '交通',
          description: '打车',
          type: 'EXPENSE',
          confidence: 0.90,
          source: ParseSource.llm,
        ),
      ];
      final orchestrator = createOrchestrator();

      final results = await orchestrator.parse('花了60还有30');

      expect(results, hasLength(2));
      expect(results[0].amount, 60.0);
      expect(results[0].source, ParseSource.llm);
      expect(results[1].amount, 30.0);
    });

    test('offline returns single-element list from local engine', () async {
      fakeNetwork.online = false;
      final orchestrator = createOrchestrator();

      final results = await orchestrator.parse('花了100');

      expect(results, hasLength(1));
      expect(results[0].source, ParseSource.local);
      expect(results[0].amount, 100.0);
      expect(results[0].confidence, 0.3);
    });

    test('LLM failure falls back to single-element local list', () async {
      fakeNetwork.online = true;
      fakeLlmRepo.shouldFail = true;
      final orchestrator = createOrchestrator();

      final results = await orchestrator.parse('花了100');

      expect(results, hasLength(1));
      expect(results[0].source, ParseSource.local);
      expect(results[0].confidence, 0.3);
    });

    test('single-item LLM response returns list of size 1', () async {
      fakeNetwork.online = true;
      fakeLlmRepo.nextParseResults = [
        const ParseResult(
          amount: 35,
          category: '餐饮',
          description: '午饭',
          type: 'EXPENSE',
          confidence: 0.95,
          source: ParseSource.llm,
        ),
      ];
      final orchestrator = createOrchestrator();

      final results = await orchestrator.parse('花了35');

      expect(results, hasLength(1));
      expect(results[0].source, ParseSource.llm);
    });
  });

  group('correct', () {
    late DraftBatch draftBatch;

    setUp(() {
      draftBatch = DraftBatch.fromResults(const [
        ParseResult(
          amount: 60,
          category: '餐饮',
          type: 'EXPENSE',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
        ParseResult(
          amount: 30,
          category: '交通',
          type: 'EXPENSE',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
      ]);
    });

    test('returns LLM correction response when online', () async {
      fakeNetwork.online = true;
      fakeLlmRepo.nextCorrectionResponse = const TransactionCorrectionResponse(
        corrections: [
          CorrectionItem(index: 0, updatedFields: {'amount': 50.0}),
        ],
        intent: CorrectionIntent.correction,
        confidence: 0.92,
        model: 'qwen-turbo',
      );
      final orchestrator = createOrchestrator();

      final response = await orchestrator.correct('改成50', draftBatch);

      expect(response.intent, CorrectionIntent.correction);
      expect(response.corrections[0].updatedFields['amount'], 50.0);
    });

    test('low confidence (< 0.7) returns unclear intent', () async {
      fakeNetwork.online = true;
      fakeLlmRepo.nextCorrectionResponse = const TransactionCorrectionResponse(
        corrections: [
          CorrectionItem(index: 0, updatedFields: {'amount': 50.0}),
        ],
        intent: CorrectionIntent.correction,
        confidence: 0.5,
        model: 'qwen-turbo',
      );
      final orchestrator = createOrchestrator();

      final response = await orchestrator.correct('改成50', draftBatch);

      expect(response.intent, CorrectionIntent.unclear);
      expect(response.confidence, 0.5);
    });

    test('offline uses local correction', () async {
      fakeNetwork.online = false;
      final orchestrator = createOrchestrator();

      final response = await orchestrator.correct('改成50', draftBatch);

      expect(response.model, 'local');
      expect(response.intent, CorrectionIntent.correction);
      expect(response.corrections[0].updatedFields['amount'], 50.0);
    });

    test('LLM timeout falls back to local correction', () async {
      fakeNetwork.online = true;
      fakeLlmRepo.correctionDelay = const Duration(seconds: 5);
      fakeLlmRepo.nextCorrectionResponse = const TransactionCorrectionResponse(
        corrections: [
          CorrectionItem(index: 0, updatedFields: {'amount': 99.0}),
        ],
        intent: CorrectionIntent.correction,
        confidence: 0.95,
        model: 'qwen-turbo',
      );
      final orchestrator = createOrchestrator();

      final response = await orchestrator.correct('改成50', draftBatch);

      expect(response.model, 'local');
      expect(response.corrections[0].updatedFields['amount'], 50.0);
    });

    test('local correction returns unclear when no match', () async {
      fakeNetwork.online = false;
      final orchestrator = createOrchestrator();

      final response = await orchestrator.correct('嗯嗯嗯', draftBatch);

      expect(response.intent, CorrectionIntent.unclear);
      expect(response.corrections, isEmpty);
    });

    test('local type correction works offline', () async {
      fakeNetwork.online = false;
      final orchestrator = createOrchestrator();

      final response = await orchestrator.correct('应该是收入', draftBatch);

      expect(response.intent, CorrectionIntent.correction);
      expect(response.corrections[0].updatedFields['type'], 'INCOME');
    });

    test('single-item batch correction compatible', () async {
      fakeNetwork.online = true;
      final singleBatch = DraftBatch.fromResults(const [
        ParseResult(
          amount: 60,
          category: '餐饮',
          type: 'EXPENSE',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
      ]);
      fakeLlmRepo.nextCorrectionResponse = const TransactionCorrectionResponse(
        corrections: [
          CorrectionItem(index: 0, updatedFields: {'amount': 50.0}),
        ],
        intent: CorrectionIntent.correction,
        confidence: 0.92,
        model: 'qwen-turbo',
      );
      final orchestrator = createOrchestrator();

      final response = await orchestrator.correct('改成50', singleBatch);

      expect(response.corrections, hasLength(1));
      expect(response.corrections[0].updatedFields['amount'], 50.0);
    });
  });
}

class _FakeNetworkStatus implements NetworkStatusService {
  bool online = true;

  @override
  bool get isOnline => online;

  @override
  Stream<bool> get onStatusChange => const Stream.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeLlmRepository extends LlmRepository {
  List<ParseResult> nextParseResults = [];
  TransactionCorrectionResponse? nextCorrectionResponse;
  bool shouldFail = false;
  bool shouldFailCorrection = false;
  Duration? correctionDelay;

  _FakeLlmRepository(super.apiClient);

  @override
  Future<List<ParseResult>> parseTransaction({
    required String text,
    List<String>? recentCategories,
    List<String>? customCategories,
    List<String>? accounts,
  }) async {
    if (shouldFail) throw const LlmParseException('Fake LLM failure');
    return nextParseResults;
  }

  @override
  Future<TransactionCorrectionResponse> correctTransaction({
    required List<BatchItem> currentBatch,
    required String correctionText,
    List<String>? recentCategories,
    List<String>? customCategories,
  }) async {
    if (shouldFailCorrection) {
      throw const LlmParseException('Fake correction failure');
    }
    if (correctionDelay != null) {
      await Future<void>.delayed(correctionDelay!);
    }
    return nextCorrectionResponse!;
  }
}
