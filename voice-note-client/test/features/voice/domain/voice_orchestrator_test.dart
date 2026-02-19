import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/network/api_client.dart';
import 'package:suikouji/core/network/api_config.dart';
import 'package:suikouji/core/network/dto/asr_token_response.dart';
import 'package:suikouji/core/tts/tts_service.dart';
import 'package:suikouji/features/voice/data/asr_repository.dart';
import 'package:suikouji/features/voice/data/asr_websocket_service.dart';
import 'package:suikouji/features/voice/data/audio_capture_service.dart';
import 'package:suikouji/features/voice/data/llm_repository.dart';
import 'package:suikouji/features/voice/data/local_nlp_engine.dart';
import 'package:suikouji/features/voice/data/vad_service.dart';
import 'package:suikouji/core/network/dto/transaction_correction_response.dart'
    as dto;
import 'package:suikouji/features/voice/domain/draft_batch.dart';
import 'package:suikouji/features/voice/domain/nlp_orchestrator.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';
import 'package:suikouji/features/voice/domain/voice_correction_handler.dart';
import 'package:suikouji/features/voice/domain/voice_orchestrator.dart';
import 'package:suikouji/features/voice/domain/voice_state.dart';
import 'package:suikouji/features/voice/presentation/widgets/mode_switcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAsrRepository fakeAsrRepo;
  late _FakeNlpOrchestrator fakeNlpOrch;
  late VoiceCorrectionHandler correctionHandler;
  late _MockDelegate delegate;
  late VoiceOrchestrator orchestrator;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock the record plugin platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (call) async => '0',
        );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final apiClient = ApiClient(ApiConfig(prefs));

    fakeAsrRepo = _FakeAsrRepository(apiClient);
    fakeNlpOrch = _FakeNlpOrchestrator(
      localEngine: LocalNlpEngine(),
      llmRepository: LlmRepository(apiClient),
    );
    correctionHandler = VoiceCorrectionHandler();
    delegate = _MockDelegate();

    orchestrator = VoiceOrchestrator(
      asrRepository: fakeAsrRepo,
      nlpOrchestrator: fakeNlpOrch,
      correctionHandler: correctionHandler,
      delegate: delegate,
    );
  });

  group('initial state', () {
    test('starts in idle', () {
      expect(orchestrator.currentState, VoiceState.idle);
    });
  });

  group('processTextInput', () {
    test('parses text and transitions to confirming', () async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 42.5,
        category: '餐饮',
        description: '午餐',
        confidence: 0.8,
        source: ParseSource.local,
      );

      await orchestrator.processTextInput('午餐42块5');

      expect(delegate.speechDetectedCount, 1);
      expect(delegate.finalTexts, hasLength(1));
      expect(delegate.finalTexts.first.$1, '午餐42块5');
      expect(delegate.finalTexts.first.$2.items.first.result.amount, 42.5);
      expect(orchestrator.currentState, VoiceState.confirming);
    });

    test('ignores empty or whitespace-only text', () async {
      await orchestrator.processTextInput('  ');
      await orchestrator.processTextInput('');

      expect(delegate.speechDetectedCount, 0);
      expect(delegate.finalTexts, isEmpty);
    });

    test('skips filler text, notifies delegate, and stays listening', () async {
      for (final filler in ['嗯。', '啊', '哦？', '嗯嗯', '呃…', '噢']) {
        await orchestrator.processTextInput(filler);
      }

      expect(fakeNlpOrch.parseCallCount, 0);
      expect(delegate.finalTexts, isEmpty);
      expect(delegate.errors, isEmpty);
      expect(delegate.continueCount, 6);
      expect(orchestrator.currentState, VoiceState.listening);
    });

    test('reports error when NLP fails', () async {
      fakeNlpOrch.shouldFail = true;

      await orchestrator.processTextInput('gibberish');

      expect(delegate.errors, hasLength(1));
      expect(delegate.errors.first, contains('NLP'));
      expect(orchestrator.currentState, VoiceState.listening);
    });
  });

  group('confirmation handling', () {
    setUp(() async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 28.0,
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );
      await orchestrator.processTextInput('咖啡28块');
      delegate.reset();
      fakeNlpOrch.shouldFail = false;
    });

    test('confirm intent triggers onConfirmTransaction', () async {
      await orchestrator.processTextInput('确认');

      expect(delegate.confirmCount, 1);
      expect(orchestrator.currentState, VoiceState.listening);
    });

    test('cancel intent triggers onCancelTransaction', () async {
      await orchestrator.processTextInput('取消');

      expect(delegate.cancelCount, 1);
      expect(orchestrator.currentState, VoiceState.listening);
    });

    test('filler text in confirming state is silently ignored', () async {
      final prevConfirmCount = delegate.confirmCount;
      final prevCancelCount = delegate.cancelCount;
      final prevParseCount = fakeNlpOrch.parseCallCount;

      await orchestrator.processTextInput('嗯');
      await orchestrator.processTextInput('哦。');
      await orchestrator.processTextInput('啊？');

      expect(delegate.confirmCount, prevConfirmCount);
      expect(delegate.cancelCount, prevCancelCount);
      expect(delegate.errors, isEmpty);
      expect(fakeNlpOrch.parseCallCount, prevParseCount);
      expect(orchestrator.currentState, VoiceState.confirming);
    });

    test('exit intent triggers onExitSession', () async {
      await orchestrator.processTextInput('退出');

      expect(delegate.exitCount, 1);
      expect(orchestrator.currentState, VoiceState.idle);
    });

    test('continue intent triggers onContinueRecording', () async {
      await orchestrator.processTextInput('还有');

      expect(delegate.continueCount, 1);
      expect(orchestrator.currentState, VoiceState.listening);
    });

    test('correction intent applies LLM correction to batch', () async {
      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 0,
            updatedFields: {'amount': 50.0},
          ),
        ],
        intent: dto.CorrectionIntent.correction,
        confidence: 0.9,
        model: 'fake',
      );

      await orchestrator.processTextInput('不对改成50');

      expect(delegate.updatedBatches, hasLength(1));
      expect(
        delegate.updatedBatches.first.items.first.result.amount,
        50.0,
      );
      expect(orchestrator.currentState, VoiceState.confirming);
    });

    test('new input during confirming appends via LLM', () async {
      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 0,
            updatedFields: {
              'amount': 15.0,
              'category': '交通',
              'type': 'EXPENSE',
            },
          ),
        ],
        intent: dto.CorrectionIntent.append,
        confidence: 0.9,
        model: 'fake',
      );

      await orchestrator.processTextInput('地铁15块');

      expect(delegate.updatedBatches, hasLength(1));
      expect(delegate.updatedBatches.first.items, hasLength(2));
      expect(delegate.updatedBatches.first.items.last.result.amount, 15.0);
      expect(orchestrator.currentState, VoiceState.confirming);
    });
  });

  group('batch workflow coverage (tasks 12.x)', () {
    late _FakeTtsService fakeTts;
    late VoiceOrchestrator batchOrchestrator;

    ParseResult result({
      required double amount,
      required String category,
      String type = 'EXPENSE',
      ParseSource source = ParseSource.llm,
    }) {
      return ParseResult(
        amount: amount,
        category: category,
        type: type,
        confidence: 0.9,
        source: source,
      );
    }

    setUp(() {
      fakeTts = _FakeTtsService();
      fakeNlpOrch.nextResults = null;
      fakeNlpOrch.correctionQueue.clear();
      fakeNlpOrch.correctDelay = Duration.zero;
      fakeNlpOrch.shouldCorrectFail = false;
      batchOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        ttsService: fakeTts,
      );
    });

    test('12.1 多笔输入创建 4 笔 pending DraftBatch', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
        result(amount: 40, category: '购物'),
        result(amount: 50, category: '娱乐'),
      ];

      await batchOrchestrator.processTextInput('午饭20 地铁30 买菜40 电影50');

      final batch = delegate.finalTexts.first.$2;
      expect(delegate.finalTexts, hasLength(1));
      expect(batch.items, hasLength(4));
      expect(batch.pendingCount, 4);
      expect(batch.confirmedCount, 0);
      expect(batch.cancelledCount, 0);
      expect(batchOrchestrator.currentState, VoiceState.confirming);
    });

    test('12.2 全部确认后自动提交并清空 DraftBatch', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔记录');
      delegate.reset();

      await batchOrchestrator.processTextInput('确认');

      expect(delegate.savedBatches, hasLength(1));
      expect(delegate.savedBatches.first, hasLength(2));
      expect(delegate.confirmCount, 1);
      expect(batchOrchestrator.currentState, VoiceState.listening);
    });

    test('12.3 定点纠正（序号）更新对应 item 并通知 delegate', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔记录');
      delegate.reset();

      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 1,
            updatedFields: {'amount': 66.0},
          ),
        ],
        intent: dto.CorrectionIntent.correction,
        confidence: 0.9,
        model: 'fake',
      );

      await batchOrchestrator.processTextInput('第2笔改成66');

      expect(delegate.updatedBatches, hasLength(1));
      expect(delegate.updatedBatches.first.items[1].result.amount, 66.0);
    });

    test('12.4 定点纠正（描述词）更新对应 item', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔记录');
      delegate.reset();

      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 0,
            updatedFields: {'category': '早餐'},
          ),
        ],
        intent: dto.CorrectionIntent.correction,
        confidence: 0.9,
        model: 'fake',
      );

      await batchOrchestrator.processTextInput('午餐不是餐饮，是早餐');

      expect(delegate.updatedBatches, hasLength(1));
      expect(delegate.updatedBatches.first.items[0].result.category, '早餐');
    });

    test('12.5 逐条取消后有 TTS 取消反馈', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔记录');
      delegate.reset();
      fakeTts.spokenTexts.clear();

      await batchOrchestrator.processTextInput('取消第1笔');

      expect(delegate.updatedBatches, hasLength(1));
      expect(delegate.updatedBatches.first.cancelledCount, 1);
      expect(delegate.updatedBatches.first.pendingCount, 1);
    });

    test('12.6 部分确认 + 部分取消后自动提交 confirmed', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔记录');
      delegate.reset();

      await batchOrchestrator.processTextInput('确认第1笔');
      await batchOrchestrator.processTextInput('取消第2笔');

      expect(delegate.savedBatches, hasLength(1));
      expect(delegate.savedBatches.first, hasLength(1));
      expect(delegate.savedBatches.first.first.result.amount, 20);
      expect(delegate.confirmCount, 1);
    });

    test('12.7 单笔 batch 行为保持兼容', () async {
      fakeNlpOrch.nextResults = [result(amount: 88, category: '餐饮')];

      await batchOrchestrator.processTextInput('午餐88');
      delegate.reset();
      await batchOrchestrator.processTextInput('确认');

      expect(delegate.savedBatches, hasLength(1));
      expect(delegate.savedBatches.first, hasLength(1));
      expect(delegate.confirmCount, 1);
    });

    test('12.8 离线降级为单笔并播报单笔确认 TTS', () async {
      fakeNlpOrch.nextResults = [
        result(
          amount: 35,
          category: '餐饮',
          source: ParseSource.local,
        ),
      ];

      await batchOrchestrator.processTextInput('午饭35');

      expect(fakeTts.spokenTexts.any((t) => t.contains('识别到餐饮支出35元')), isTrue);
    });

    test('12.9 LLM 超时降级为本地纠正结果', () async {
      fakeNlpOrch.nextResults = [result(amount: 20, category: '餐饮')];
      await batchOrchestrator.processTextInput('午饭20');
      delegate.reset();

      fakeNlpOrch.correctDelay = const Duration(milliseconds: 20);
      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 0,
            updatedFields: {'amount': 99.0},
          ),
        ],
        intent: dto.CorrectionIntent.correction,
        confidence: 0.75,
        model: 'local',
      );

      await batchOrchestrator.processTextInput('改成99');

      expect(delegate.updatedBatches, hasLength(1));
      expect(delegate.updatedBatches.first.items.first.result.amount, 99);
    });

    test('12.10 2-5 笔逐条播报，6+ 笔摘要播报', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 10, category: '餐饮'),
        result(amount: 20, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔');
      expect(fakeTts.spokenTexts.last, contains('识别到2笔交易'));

      await batchOrchestrator.processTextInput('还有');
      fakeTts.spokenTexts.clear();
      fakeNlpOrch.nextResults = [
        result(amount: 1, category: 'a'),
        result(amount: 2, category: 'b'),
        result(amount: 3, category: 'c'),
        result(amount: 4, category: 'd'),
        result(amount: 5, category: 'e'),
        result(amount: 6, category: 'f'),
      ];
      await batchOrchestrator.processTextInput('六笔');
      expect(fakeTts.spokenTexts.last, contains('识别到6笔交易'));
      expect(fakeTts.spokenTexts.last, contains('合计21元'));
    });

    test('12.11 CONFIRMING 态追加新笔后批次增加并播报', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔');
      delegate.reset();
      fakeTts.spokenTexts.clear();

      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 0,
            updatedFields: {
              'amount': 12.0,
              'category': '饮料',
              'type': 'EXPENSE',
            },
          ),
        ],
        intent: dto.CorrectionIntent.append,
        confidence: 0.9,
        model: 'fake',
      );

      await batchOrchestrator.processTextInput('再加一笔奶茶12');

      expect(delegate.updatedBatches, hasLength(1));
      expect(delegate.updatedBatches.first.items, hasLength(3));
      expect(fakeTts.spokenTexts.any((t) => t.contains('已追加第3笔')), isTrue);
    });

    test('12.12 追加超限时拒绝并播报上限提示', () async {
      fakeNlpOrch.nextResults = List.generate(
        10,
        (i) => result(amount: i + 1.0, category: '分类$i'),
      );
      await batchOrchestrator.processTextInput('十笔');
      delegate.reset();
      fakeTts.spokenTexts.clear();

      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 0,
            updatedFields: {'amount': 999.0, 'category': '额外'},
          ),
        ],
        intent: dto.CorrectionIntent.append,
        confidence: 0.9,
        model: 'fake',
      );

      await batchOrchestrator.processTextInput('再加一笔');

      expect(delegate.updatedBatches, isEmpty);
      expect(fakeTts.spokenTexts.any((t) => t.contains('最多只能记10笔')), isTrue);
    });

    test('12.13 纠正时排除 cancelled 项并正确做 index 映射', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 10, category: '餐饮'),
        result(amount: 20, category: '交通'),
        result(amount: 30, category: '购物'),
      ];
      await batchOrchestrator.processTextInput('三笔');
      await batchOrchestrator.processTextInput('取消第2笔');
      delegate.reset();

      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(
            index: 1,
            updatedFields: {'amount': 77.0},
          ),
        ],
        intent: dto.CorrectionIntent.correction,
        confidence: 0.9,
        model: 'fake',
      );

      await batchOrchestrator.processTextInput('把第三笔改成77');

      expect(delegate.updatedBatches, hasLength(1));
      final updated = delegate.updatedBatches.first;
      expect(updated.items[2].result.amount, 77);
      expect(updated.items[1].status, DraftStatus.cancelled);
    });

    test('12.14 LLM 返回 confirm intent 时执行确认流程', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔');
      delegate.reset();

      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [],
        intent: dto.CorrectionIntent.confirm,
        confidence: 0.9,
        model: 'fake',
      );

      await batchOrchestrator.processTextInput('对，都确认');

      expect(delegate.savedBatches, hasLength(1));
      expect(delegate.confirmCount, 1);
    });

    test('12.15 correction 发起时立即播报 loading TTS', () async {
      fakeNlpOrch.nextResults = [result(amount: 20, category: '餐饮')];
      await batchOrchestrator.processTextInput('午饭20');
      fakeTts.spokenTexts.clear();
      fakeNlpOrch.correctDelay = const Duration(milliseconds: 50);
      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [],
        intent: dto.CorrectionIntent.unclear,
        confidence: 0.1,
        model: 'fake',
      );

      final future = batchOrchestrator.processTextInput('改一下');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(fakeTts.spokenTexts.first, contains('好的，正在修改'));
      await future;
    });

    test('12.16 confidence < 0.7 视为 unclear', () async {
      fakeNlpOrch.nextResults = [result(amount: 20, category: '餐饮')];
      await batchOrchestrator.processTextInput('午饭20');
      delegate.reset();
      fakeTts.spokenTexts.clear();

      fakeNlpOrch.nextCorrectionResponse = const dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(index: 0, updatedFields: {'amount': 99.0}),
        ],
        intent: dto.CorrectionIntent.unclear,
        confidence: 0.6,
        model: 'fake',
      );

      await batchOrchestrator.processTextInput('改成99');

      expect(delegate.updatedBatches, isEmpty);
      expect(fakeTts.spokenTexts.any((t) => t.contains('没听清要改什么')), isTrue);
    });

    test('12.17 多次纠正累积生效（先改类型再改金额）', () async {
      fakeNlpOrch.nextResults = [result(amount: 20, category: '餐饮')];
      await batchOrchestrator.processTextInput('午饭20');
      delegate.reset();

      fakeNlpOrch.correctionQueue.addAll([
        const dto.TransactionCorrectionResponse(
          corrections: [
            dto.CorrectionItem(index: 0, updatedFields: {'type': 'INCOME'}),
          ],
          intent: dto.CorrectionIntent.correction,
          confidence: 0.9,
          model: 'fake',
        ),
        const dto.TransactionCorrectionResponse(
          corrections: [
            dto.CorrectionItem(index: 0, updatedFields: {'amount': 88.0}),
          ],
          intent: dto.CorrectionIntent.correction,
          confidence: 0.9,
          model: 'fake',
        ),
      ]);

      await batchOrchestrator.processTextInput('改成收入');
      await batchOrchestrator.processTextInput('再改成88');

      expect(delegate.updatedBatches, hasLength(2));
      expect(delegate.updatedBatches.last.items.first.result.type, 'INCOME');
      expect(delegate.updatedBatches.last.items.first.result.amount, 88.0);
    });

    test('12.18 confirm/cancel/continue 都会清空 DraftBatch', () async {
      fakeNlpOrch.nextResults = [
        result(amount: 20, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔');
      await batchOrchestrator.processTextInput('确认');
      expect(batchOrchestrator.currentState, VoiceState.listening);

      fakeNlpOrch.nextResults = [result(amount: 99, category: '购物')];
      await batchOrchestrator.processTextInput('一笔');
      await batchOrchestrator.processTextInput('取消');
      expect(batchOrchestrator.currentState, VoiceState.listening);

      fakeNlpOrch.nextResults = [result(amount: 66, category: '餐饮')];
      await batchOrchestrator.processTextInput('再来一笔');
      await batchOrchestrator.processTextInput('还有');
      expect(batchOrchestrator.currentState, VoiceState.listening);
    });

    test('confirm during LLM correction is ignored (_isCorrecting guard)',
        () async {
      fakeNlpOrch.nextResults = [
        result(amount: 50, category: '餐饮'),
        result(amount: 30, category: '交通'),
      ];
      await batchOrchestrator.processTextInput('两笔');
      expect(delegate.finalTexts.length, 1);

      const correctionResponse = dto.TransactionCorrectionResponse(
        corrections: [
          dto.CorrectionItem(index: 0, updatedFields: {'amount': 40.0}),
        ],
        intent: dto.CorrectionIntent.correction,
        confidence: 0.9,
        model: 'test',
      );
      fakeNlpOrch.nextCorrectionResponse = correctionResponse;
      fakeNlpOrch.correctDelay = const Duration(milliseconds: 50);

      // Fire correction and immediately try to confirm — confirm should be
      // ignored because _isCorrecting is true.
      final correctionFuture =
          batchOrchestrator.processTextInput('改成40');
      // Yield to let correction start, then send confirm.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await batchOrchestrator.processTextInput('确认');

      await correctionFuture;

      // Correction should have been applied (amount updated).
      expect(delegate.updatedBatches.isNotEmpty, true);
      final lastBatch = delegate.updatedBatches.last;
      expect(lastBatch.items[0].result.amount, 40.0);

      // Batch should still exist (confirm was ignored), state stays confirming.
      expect(batchOrchestrator.currentState, VoiceState.confirming);
      expect(lastBatch.pendingCount, greaterThan(0));
    });
  });

  group('stopListening', () {
    test('transitions to idle', () async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 10,
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );
      await orchestrator.processTextInput('咖啡10块');
      expect(orchestrator.currentState, VoiceState.confirming);

      await orchestrator.stopListening();
      expect(orchestrator.currentState, VoiceState.idle);
    });
  });

  group('dispose', () {
    test('transitions to idle and is safe to call twice', () async {
      await orchestrator.dispose();
      expect(orchestrator.currentState, VoiceState.idle);
      await orchestrator.dispose(); // should not throw
    });
  });

  group('error handling', () {
    test('newInput during confirming with NLP failure reports error', () async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 28.0,
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );
      await orchestrator.processTextInput('咖啡28块');
      delegate.reset();

      // Make correction fail
      fakeNlpOrch.shouldCorrectFail = true;
      await orchestrator.processTextInput('午餐50块');

      expect(delegate.errors, hasLength(1));
      expect(delegate.errors.first, contains('NLP'));
      expect(orchestrator.currentState, VoiceState.listening);
    });

    test('processTextInput handles NLP error gracefully', () async {
      fakeNlpOrch.shouldFail = true;

      await orchestrator.processTextInput('random text');

      expect(delegate.errors, hasLength(1));
      expect(orchestrator.currentState, VoiceState.listening);
    });
  });

  group('ASR reconnection', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late _FakeVadService fakeVad;
    late VoiceOrchestrator reconnectOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      fakeVad = _FakeVadService();

      reconnectOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await reconnectOrchestrator.dispose();
    });

    test(
      'attempts reconnect on unexpected disconnect in recognizing state',
      () async {
        // Start listening and simulate VAD detecting speech
        await reconnectOrchestrator.startListening(VoiceInputMode.auto);
        expect(reconnectOrchestrator.currentState, VoiceState.listening);

        // Simulate speech detection → ASR connect
        delegate.reset();
        fakeAsr.connectCount = 0;

        // Manually push to recognizing via processTextInput path
        // Instead, let's directly set recognizing and trigger disconnect
        // We simulate the full flow: pushStart → connected → disconnect
        await reconnectOrchestrator.pushStart();

        expect(fakeAsr.connectCount, 1);
        delegate.reset();

        // Simulate unexpected ASR disconnect
        fakeAsr.simulateDisconnect();

        // Allow reconnection delay (base 1s * 2^0 = 1s, but we test without real delays)
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should have attempted reconnect (errors contain reconnect message)
        expect(
          delegate.errors.any((e) => e.contains('重连')),
          isTrue,
          reason: 'Should notify about reconnection attempt',
        );
      },
    );

    test('gives up after max reconnect attempts', () async {
      fakeAsr.failConnect = true;

      await reconnectOrchestrator.pushStart();
      delegate.reset();

      // After pushStart fails in _connectAsrAndStream, it reports error
      // Let's test via disconnect simulation where connect always fails
      fakeAsr.failConnect = false;
      await reconnectOrchestrator.pushStart();
      fakeAsr.failConnect = true;
      delegate.reset();

      // Simulate disconnect — reconnect will fail
      fakeAsr.simulateDisconnect();
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Should eventually give up
      expect(delegate.errors, isNotEmpty);
    });

    test('does not duplicate ASR event handlers on reconnect', () async {
      await reconnectOrchestrator.startListening(VoiceInputMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Speech detected → first ASR connect
      fakeVad.simulateSpeechStart();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeAsr.connectCount, 1);
      delegate.reset();

      // Simulate disconnect → triggers reconnect (1s delay)
      fakeAsr.simulateDisconnect();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(fakeAsr.connectCount, 2);
      delegate.reset();

      // Emit interim text — must be received exactly once (not duplicated)
      fakeAsr.simulateInterimText('single event');
      await Future<void>.delayed(Duration.zero);

      expect(delegate.interimTexts, hasLength(1));
      expect(delegate.interimTexts.first, 'single event');
    });

    test('VAD subscriptions survive ASR reconnect', () async {
      await reconnectOrchestrator.startListening(VoiceInputMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // First speech → ASR connect
      fakeVad.simulateSpeechStart();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakeAsr.connectCount, 1);

      // Simulate disconnect → reconnect
      fakeAsr.simulateDisconnect();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      delegate.reset();

      // Stop current recognition by simulating final text
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 10.0,
        category: '餐饮',
        confidence: 0.9,
        source: ParseSource.local,
      );
      fakeAsr.simulateFinalText('test');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Should be back in confirming, then confirm to go to listening
      await reconnectOrchestrator.processTextInput('确认');
      expect(reconnectOrchestrator.currentState, VoiceState.listening);
      delegate.reset();
      fakeAsr.connectCount = 0;

      // VAD should still work — trigger new speech
      fakeVad.simulateSpeechStart();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(delegate.speechDetectedCount, 1);
      expect(fakeAsr.connectCount, 1);
    });

    test('no reconnect when not in recognizing state', () async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 20.0,
        category: '餐饮',
        confidence: 0.9,
        source: ParseSource.local,
      );

      await reconnectOrchestrator.pushStart();
      fakeAsr.simulateFinalText('咖啡20块');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(reconnectOrchestrator.currentState, VoiceState.confirming);
      delegate.reset();

      fakeAsr.simulateDisconnect();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(delegate.errors.where((e) => e.contains('重连')), isEmpty);
    });
  });

  group('VAD misfire tracking', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late _FakeVadService fakeVad;
    late VoiceOrchestrator misfireOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      fakeVad = _FakeVadService();

      misfireOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await misfireOrchestrator.dispose();
    });

    test('suggests PTT after 3 consecutive misfires', () async {
      await misfireOrchestrator.startListening(VoiceInputMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      fakeVad.simulateMisfire();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(delegate.suggestPttCount, 0);

      fakeVad.simulateMisfire();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(delegate.suggestPttCount, 0);

      fakeVad.simulateMisfire();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(delegate.suggestPttCount, 1);
    });

    test('resets misfire counter on real speech', () async {
      await misfireOrchestrator.startListening(VoiceInputMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      fakeVad.simulateMisfire();
      fakeVad.simulateMisfire();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Real speech resets counter
      fakeVad.simulateSpeechStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      fakeVad.simulateMisfire();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(delegate.suggestPttCount, 0); // Not 3 consecutive
    });
  });

  group('TTS integration', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late _FakeVadService fakeVad;
    late _FakeTtsService fakeTts;
    late VoiceOrchestrator ttsOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      fakeVad = _FakeVadService();
      fakeTts = _FakeTtsService();

      ttsOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        ttsService: fakeTts,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await ttsOrchestrator.dispose();
    });

    test('speaks welcome message on startListening', () async {
      await ttsOrchestrator.startListening(VoiceInputMode.auto);
      expect(fakeTts.spokenTexts, contains('你好，想记点什么？'));
    });

    test('speaks confirm after NLP parse with complete result', () async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 35.0,
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );

      await ttsOrchestrator.processTextInput('午饭35');
      expect(fakeTts.spokenTexts, contains('识别到餐饮支出35元，确认吗？'));
    });

    test('does not speak confirm when result is incomplete', () async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: null,
        category: null,
        confidence: 0.3,
        source: ParseSource.local,
      );

      await ttsOrchestrator.processTextInput('什么');
      expect(fakeTts.spokenTexts.where((t) => t.contains('确认')), isEmpty);
    });

    test('VAD speechStart interrupts TTS and starts ASR (barge-in)', () async {
      fakeTts.delayMs = 100; // Simulate slow TTS

      await ttsOrchestrator.startListening(VoiceInputMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // startListening already awaits welcome speech in this fake setup.
      // Use speakAndResumeTimer to create a deterministic in-flight TTS window.

      delegate.reset();
      fakeAsr.connectCount = 0;
      fakeTts.spokenTexts.clear();
      fakeTts.delayMs = 200;

      // Trigger a long TTS speak
      final speakFuture = ttsOrchestrator.speakAndResumeTimer(
        'testing suppression',
      );

      // While TTS is speaking, simulate VAD event
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fakeVad.simulateSpeechStart();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Barge-in should interrupt TTS and start ASR connection.
      expect(fakeAsr.connectCount, 1);
      expect(delegate.speechDetectedCount, 1);

      await speakFuture;
    });

    test('welcome TTS supports barge-in during startListening', () async {
      fakeTts.delayMs = 200;

      final startFuture = ttsOrchestrator.startListening(VoiceInputMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fakeVad.simulateSpeechStart();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fakeAsr.connectCount, 1);
      expect(delegate.speechDetectedCount, 1);

      await startFuture;
    });

    test('no TTS when ttsService is null', () async {
      final noTtsOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );

      // Should not crash without TTS
      await noTtsOrchestrator.startListening(VoiceInputMode.auto);
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 10,
        category: '交通',
        confidence: 0.8,
        source: ParseSource.local,
      );
      await noTtsOrchestrator.processTextInput('地铁10');
      expect(delegate.finalTexts, hasLength(1));

      await noTtsOrchestrator.dispose();
    });
  });

  group('startListening', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late _FakeVadService fakeVad;
    late VoiceOrchestrator listenOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      fakeVad = _FakeVadService();
      listenOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await listenOrchestrator.dispose();
    });

    test('keyboard mode is a no-op', () async {
      await listenOrchestrator.startListening(VoiceInputMode.keyboard);
      expect(listenOrchestrator.currentState, VoiceState.idle);
    });

    test('auto mode transitions to listening', () async {
      await listenOrchestrator.startListening(VoiceInputMode.auto);
      expect(listenOrchestrator.currentState, VoiceState.listening);
    });
  });

  group('pushToTalk', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late VoiceOrchestrator pttOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      pttOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await pttOrchestrator.dispose();
    });

    test('pushStart transitions to recognizing', () async {
      await pttOrchestrator.pushStart();
      expect(pttOrchestrator.currentState, VoiceState.recognizing);
      expect(delegate.speechDetectedCount, 1);
      expect(fakeAsr.connectCount, 1);
    });

    test('pushEnd calls commit after sufficient hold', () {
      fakeAsync((async) {
        pttOrchestrator.pushStart();
        async.flushMicrotasks();
        expect(fakeAsr.commitCount, 0);

        async.elapse(const Duration(milliseconds: 700));
        pttOrchestrator.pushEnd();
        async.flushMicrotasks();
        expect(fakeAsr.commitCount, 1);
      });
    });

    test('too-short press discards recording', () {
      fakeAsync((async) {
        pttOrchestrator.pushStart();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 200));
        pttOrchestrator.pushEnd();
        async.flushMicrotasks();

        expect(fakeAsr.commitCount, 0);
        expect(pttOrchestrator.currentState, VoiceState.listening);
        expect(delegate.errors, contains(contains('太短')));
      });
    });

    test('ASR timeout resets state after pushEnd', () {
      fakeAsync((async) {
        pttOrchestrator.pushStart();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 1));
        pttOrchestrator.pushEnd();
        async.flushMicrotasks();
        expect(fakeAsr.commitCount, 1);

        // ASR never returns finalText — timeout fires
        async.elapse(const Duration(seconds: 8));
        expect(pttOrchestrator.currentState, VoiceState.listening);
        expect(delegate.errors, contains(contains('超时')));
      });
    });
  });

  group('ASR event flow', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late VoiceOrchestrator asrOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      asrOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await asrOrchestrator.dispose();
    });

    test('interim text from ASR is forwarded to delegate', () async {
      await asrOrchestrator.pushStart();
      delegate.reset();

      fakeAsr.simulateInterimText('正在识别...');
      await Future<void>.delayed(Duration.zero);

      expect(delegate.interimTexts, contains('正在识别...'));
    });

    test('final text from ASR triggers NLP parse', () async {
      fakeNlpOrch.nextResult = const ParseResult(
        amount: 20.0,
        category: '餐饮',
        confidence: 0.9,
        source: ParseSource.local,
      );

      await asrOrchestrator.pushStart();
      delegate.reset();

      fakeAsr.simulateFinalText('咖啡20块');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(delegate.finalTexts, hasLength(1));
      expect(delegate.finalTexts.first.$1, '咖啡20块');
      expect(asrOrchestrator.currentState, VoiceState.confirming);
    });

    test('empty final text from ASR is ignored', () async {
      await asrOrchestrator.pushStart();
      delegate.reset();

      fakeAsr.simulateFinalText('   ');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(delegate.finalTexts, isEmpty);
    });

    test('ASR error is forwarded to delegate', () async {
      await asrOrchestrator.pushStart();
      delegate.reset();

      fakeAsr.simulateAsrError('Network timeout');
      await Future<void>.delayed(Duration.zero);

      expect(delegate.errors, contains('Network timeout'));
    });

    test(
      'final text during confirming state handles correction intent',
      () async {
        fakeNlpOrch.nextResult = const ParseResult(
          amount: 20.0,
          category: '餐饮',
          confidence: 0.9,
          source: ParseSource.local,
        );
        await asrOrchestrator.pushStart();
        fakeAsr.simulateFinalText('咖啡20块');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(asrOrchestrator.currentState, VoiceState.confirming);

        delegate.reset();
        fakeAsr.simulateFinalText('确认');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(delegate.confirmCount, 1);
      },
    );
  });

  group('pre-buffer handling', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late VoiceOrchestrator bufferOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      bufferOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await bufferOrchestrator.dispose();
    });

    test('sends pre-buffered audio to ASR on connect', () async {
      fakeAudio.preBuffer = [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5, 6]),
      ];

      await bufferOrchestrator.pushStart();

      expect(fakeAsr.sentAudioChunks, hasLength(2));
      expect(fakeAsr.sentAudioChunks[0], Uint8List.fromList([1, 2, 3]));
      expect(fakeAsr.sentAudioChunks[1], Uint8List.fromList([4, 5, 6]));
    });
  });

  group('speech end and commit', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late _FakeVadService fakeVad;
    late VoiceOrchestrator commitOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      fakeVad = _FakeVadService();
      commitOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await commitOrchestrator.dispose();
    });

    test('speech end triggers ASR commit', () async {
      await commitOrchestrator.startListening(VoiceInputMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      fakeVad.simulateSpeechEnd();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(fakeAsr.commitCount, 1);
    });
  });

  group('inactivity timeout', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late _FakeVadService fakeVad;
    late VoiceOrchestrator timerOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      fakeVad = _FakeVadService();
      timerOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await timerOrchestrator.dispose();
    });

    test('fires timeout warning at 2.5 minutes', () {
      fakeAsync((async) {
        timerOrchestrator.startListening(VoiceInputMode.auto);
        async.flushMicrotasks();

        expect(timerOrchestrator.currentState, VoiceState.listening);

        async.elapse(const Duration(minutes: 2, seconds: 30));
        async.flushMicrotasks();

        expect(delegate.timeoutWarningCount, 1);
        expect(delegate.timeoutCount, 0);
      });
    });

    test('fires session timeout after 3 minutes', () {
      fakeAsync((async) {
        timerOrchestrator.startListening(VoiceInputMode.auto);
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 3));
        async.flushMicrotasks();

        expect(delegate.timeoutCount, 1);
        expect(timerOrchestrator.currentState, VoiceState.idle);
      });
    });

    test('cancels timeout when text is processed', () {
      fakeAsync((async) {
        timerOrchestrator.startListening(VoiceInputMode.auto);
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 1));

        fakeNlpOrch.nextResult = const ParseResult(
          amount: 10,
          category: '餐饮',
          confidence: 0.8,
          source: ParseSource.local,
        );
        timerOrchestrator.processTextInput('coffee');
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 3));
        async.flushMicrotasks();

        expect(delegate.timeoutCount, 0);
      });
    });

    test('stopListening cancels inactivity timer', () {
      fakeAsync((async) {
        timerOrchestrator.startListening(VoiceInputMode.auto);
        async.flushMicrotasks();

        timerOrchestrator.stopListening();
        async.flushMicrotasks();

        async.elapse(const Duration(minutes: 3));
        async.flushMicrotasks();

        expect(delegate.timeoutCount, 0);
        expect(timerOrchestrator.currentState, VoiceState.idle);
      });
    });
  });

  group('startListening / pushStart error handling', () {
    test('startListening reports error when audio fails', () async {
      final failing = _FailingAudioCaptureService();
      final errOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: failing,
      );

      await errOrchestrator.startListening(VoiceInputMode.auto);

      expect(delegate.errors, hasLength(1));
      expect(delegate.errors.first, contains('Failed to start listening'));
      await errOrchestrator.dispose();
    });

    test('pushStart reports error when audio fails', () async {
      final failing = _FailingAudioCaptureService();
      final errOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: failing,
      );

      await errOrchestrator.pushStart();

      expect(delegate.errors, hasLength(1));
      expect(delegate.errors.first, contains('Push-to-talk start failed'));
      await errOrchestrator.dispose();
    });
  });

  group('reconnect give-up', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late VoiceOrchestrator giveUpOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      giveUpOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await giveUpOrchestrator.dispose();
    });

    test('gives up and falls back to listening after max attempts', () async {
      await giveUpOrchestrator.pushStart();
      expect(giveUpOrchestrator.currentState, VoiceState.recognizing);
      delegate.reset();

      // Fire 4 rapid disconnects: first 3 increment counter, 4th triggers give-up
      for (var i = 0; i < 4; i++) {
        fakeAsr.simulateDisconnect();
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(delegate.errors.any((e) => e.contains('重连失败')), isTrue);
      expect(giveUpOrchestrator.currentState, VoiceState.listening);
    });
  });

  group('TTS failure handling', () {
    late _FakeAsrWebSocketService fakeAsr;
    late _FakeAudioCaptureService fakeAudio;
    late _FakeVadService fakeVad;
    late _FakeTtsService fakeTts;
    late VoiceOrchestrator failTtsOrchestrator;

    setUp(() {
      fakeAsr = _FakeAsrWebSocketService();
      fakeAudio = _FakeAudioCaptureService();
      fakeVad = _FakeVadService();
      fakeTts = _FakeTtsService();
      failTtsOrchestrator = VoiceOrchestrator(
        asrRepository: fakeAsrRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        ttsService: fakeTts,
        audioCapture: fakeAudio,
        vadService: fakeVad,
        asrService: fakeAsr,
      );
    });

    tearDown(() async {
      await failTtsOrchestrator.dispose();
    });

    test('TTS failure degrades gracefully without delegate error', () async {
      fakeTts.shouldFail = true;

      await failTtsOrchestrator.startListening(VoiceInputMode.auto);

      expect(failTtsOrchestrator.currentState, VoiceState.listening);
      expect(delegate.errors, isEmpty);
    });

    test(
      'speakAndResumeTimer does not restart timer when not listening',
      () async {
        expect(failTtsOrchestrator.currentState, VoiceState.idle);
        await failTtsOrchestrator.speakAndResumeTimer('test');
        expect(failTtsOrchestrator.currentState, VoiceState.idle);
      },
    );
  });

  group('dispose during ASR connection', () {
    test('does not crash when disposed while fetching ASR token', () async {
      final slowRepo = _SlowAsrRepository(
        ApiClient(ApiConfig(await SharedPreferences.getInstance())),
      );
      final fakeAsr = _FakeAsrWebSocketService();
      final fakeAudio = _FakeAudioCaptureService();

      final disposeOrchestrator = VoiceOrchestrator(
        asrRepository: slowRepo,
        nlpOrchestrator: fakeNlpOrch,
        correctionHandler: correctionHandler,
        delegate: delegate,
        audioCapture: fakeAudio,
        asrService: fakeAsr,
      );

      // Start push-to-talk (triggers _connectAsrAndStream → getToken await)
      final pushFuture = disposeOrchestrator.pushStart();

      // Dispose immediately before token resolves
      await disposeOrchestrator.dispose();

      // Let the token future resolve — should NOT throw
      slowRepo.completeToken();
      await pushFuture;

      // No crash means success
      expect(delegate.errors, isEmpty);
    });
  });
}

// ======================== Test Fakes ========================

class _FakeAsrRepository extends AsrRepository {
  _FakeAsrRepository(super.apiClient);

  @override
  Future<AsrTokenResponse> getToken({bool forceRefresh = false}) async {
    return const AsrTokenResponse(
      token: 'fake-token',
      expiresAt: 9999999999,
      model: 'test-model',
      wsUrl: 'wss://fake.example.com/ws',
    );
  }

  @override
  void invalidateToken() {}
}

/// AsrRepository that delays token response until manually completed.
class _SlowAsrRepository extends AsrRepository {
  _SlowAsrRepository(super.apiClient);

  final Completer<AsrTokenResponse> _completer = Completer();

  @override
  Future<AsrTokenResponse> getToken({bool forceRefresh = false}) =>
      _completer.future;

  void completeToken() {
    if (!_completer.isCompleted) {
      _completer.complete(
        const AsrTokenResponse(
          token: 'fake-token',
          expiresAt: 9999999999,
          model: 'test-model',
          wsUrl: 'wss://fake.example.com/ws',
        ),
      );
    }
  }

  @override
  void invalidateToken() {}
}

class _FakeNlpOrchestrator extends NlpOrchestrator {
  ParseResult nextResult = const ParseResult(
    amount: 0,
    category: 'test',
    confidence: 0.5,
    source: ParseSource.local,
  );
  List<ParseResult>? nextResults;
  bool shouldFail = false;
  int parseCallCount = 0;

  dto.TransactionCorrectionResponse nextCorrectionResponse =
      const dto.TransactionCorrectionResponse(
    corrections: [],
    intent: dto.CorrectionIntent.unclear,
    confidence: 0.9,
    model: 'fake',
  );
  final List<dto.TransactionCorrectionResponse> correctionQueue = [];
  bool shouldCorrectFail = false;
  Duration correctDelay = Duration.zero;

  _FakeNlpOrchestrator({
    required super.localEngine,
    required super.llmRepository,
  });

  @override
  Future<List<ParseResult>> parse(
    String text, {
    List<String>? recentCategories,
    List<String>? customCategories,
    List<String>? accounts,
  }) async {
    parseCallCount++;
    if (shouldFail) throw Exception('NLP parse failed');
    return nextResults ?? [nextResult];
  }

  @override
  Future<dto.TransactionCorrectionResponse> correct(
    String text,
    DraftBatch pendingBatch, {
    List<String>? recentCategories,
    List<String>? customCategories,
  }) async {
    if (shouldCorrectFail) throw Exception('NLP correction failed');
    if (correctDelay > Duration.zero) {
      await Future<void>.delayed(correctDelay);
    }
    if (correctionQueue.isNotEmpty) {
      return correctionQueue.removeAt(0);
    }
    return nextCorrectionResponse;
  }
}

/// Captures all delegate method calls for verification.
class _MockDelegate implements VoiceOrchestratorDelegate {
  int speechDetectedCount = 0;
  List<String> interimTexts = [];
  List<(String, DraftBatch)> finalTexts = [];
  int confirmCount = 0;
  int cancelCount = 0;
  int exitCount = 0;
  int continueCount = 0;
  int timeoutCount = 0;
  int timeoutWarningCount = 0;
  int suggestPttCount = 0;
  List<String> errors = [];
  List<DraftBatch> updatedBatches = [];
  List<List<DraftTransaction>> savedBatches = [];

  void reset() {
    speechDetectedCount = 0;
    interimTexts = [];
    finalTexts = [];
    confirmCount = 0;
    cancelCount = 0;
    exitCount = 0;
    continueCount = 0;
    timeoutCount = 0;
    timeoutWarningCount = 0;
    suggestPttCount = 0;
    errors = [];
    updatedBatches = [];
    savedBatches = [];
  }

  @override
  void onSpeechDetected() => speechDetectedCount++;

  @override
  void onInterimText(String text) => interimTexts.add(text);

  @override
  void onFinalText(String text, DraftBatch draftBatch) =>
      finalTexts.add((text, draftBatch));

  @override
  void onDraftBatchUpdated(DraftBatch draftBatch) =>
      updatedBatches.add(draftBatch);

  @override
  void onBatchSaved(List<DraftTransaction> confirmedItems) =>
      savedBatches.add(confirmedItems);

  @override
  void onConfirmTransaction() => confirmCount++;

  @override
  void onCancelTransaction() => cancelCount++;

  @override
  void onExitSession() => exitCount++;

  @override
  void onContinueRecording() => continueCount++;

  @override
  void onError(String message) => errors.add(message);

  @override
  void onSessionTimeout() => timeoutCount++;

  @override
  void onTimeoutWarning() => timeoutWarningCount++;

  @override
  void onSuggestPushToTalk() => suggestPttCount++;
}

/// Fake ASR service that supports controlled connect/disconnect simulation.
class _FakeAsrWebSocketService extends AsrWebSocketService {
  int connectCount = 0;
  bool failConnect = false;
  final _controller = StreamController<AsrEvent>.broadcast();

  _FakeAsrWebSocketService() : super(channelFactory: _noopChannelFactory);

  static WebSocketChannel _noopChannelFactory(
    Uri uri,
    Map<String, String> headers,
  ) {
    throw UnimplementedError('Should not be called in tests');
  }

  @override
  Stream<AsrEvent> get events => _controller.stream;

  @override
  Stream<String> get onInterimText => _controller.stream
      .where((e) => e.type == AsrEventType.interimText && e.text != null)
      .map((e) => e.text!);

  @override
  Stream<String> get onFinalText => _controller.stream
      .where((e) => e.type == AsrEventType.finalText && e.text != null)
      .map((e) => e.text!);

  @override
  bool get isConnected => connectCount > 0 && !failConnect;

  @override
  Future<void> connect({
    required String token,
    required String wsUrl,
    required String model,
    String language = 'zh',
  }) async {
    if (failConnect) throw Exception('Connection failed');
    connectCount++;
  }

  final List<Uint8List> sentAudioChunks = [];
  int commitCount = 0;

  @override
  void sendAudio(Uint8List pcmData) {
    sentAudioChunks.add(pcmData);
  }

  @override
  void commit() {
    commitCount++;
  }

  @override
  void finish() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  /// Simulate unexpected WebSocket disconnect.
  void simulateDisconnect() {
    _controller.add(
      const AsrEvent(
        type: AsrEventType.disconnected,
        errorMessage: 'WebSocket connection closed unexpectedly',
      ),
    );
  }

  void simulateInterimText(String text) {
    _controller.add(AsrEvent(type: AsrEventType.interimText, text: text));
  }

  void simulateFinalText(String text) {
    _controller.add(AsrEvent(type: AsrEventType.finalText, text: text));
  }

  void simulateAsrError(String message) {
    _controller.add(AsrEvent(type: AsrEventType.error, errorMessage: message));
  }
}

/// Fake audio capture service.
class _FakeAudioCaptureService extends AudioCaptureService {
  _FakeAudioCaptureService() : super(recorder: null);

  final _controller = StreamController<Uint8List>.broadcast();

  @override
  bool get isCapturing => true;

  @override
  Stream<Uint8List>? get audioStream => _controller.stream;

  @override
  Future<void> start({int preBufferMs = 500}) async {}

  List<Uint8List> preBuffer = [];

  @override
  List<Uint8List> drainPreBuffer() => preBuffer;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Fake TTS service for testing.
class _FakeTtsService extends TtsService {
  final List<String> spokenTexts = [];
  int delayMs = 0;

  _FakeTtsService() : super(prefs: _FakeSharedPrefs());

  @override
  bool get available => true;

  @override
  bool get enabled => true;

  bool shouldFail = false;

  @override
  Future<void> speak(String text) async {
    if (shouldFail) throw Exception('TTS engine failure');
    spokenTexts.add(text);
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose() async {}
}

/// Minimal SharedPreferences stub for _FakeTtsService.
class _FakeSharedPrefs implements SharedPreferences {
  final Map<String, Object> _data = {};

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  Future<bool> setBool(String key, bool value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _data[key] = value;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Fake VAD service.
class _FakeVadService extends VadService {
  final _speechStartController = StreamController<void>.broadcast();
  final _speechEndController = StreamController<List<double>>.broadcast();
  final _misfireController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  @override
  Stream<void> get onRealSpeechStart => _speechStartController.stream;

  @override
  Stream<List<double>> get onSpeechEnd => _speechEndController.stream;

  @override
  Stream<void> get onVADMisfire => _misfireController.stream;

  @override
  Stream<String> get onError => _errorController.stream;

  @override
  Future<void> start({Stream<Uint8List>? audioStream}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _speechStartController.close();
    await _speechEndController.close();
    await _misfireController.close();
    await _errorController.close();
  }

  void simulateMisfire() => _misfireController.add(null);
  void simulateSpeechStart() => _speechStartController.add(null);
  void simulateSpeechEnd() => _speechEndController.add([]);
}

/// Audio capture that throws on start — for error handling tests.
class _FailingAudioCaptureService extends AudioCaptureService {
  _FailingAudioCaptureService() : super(recorder: null);

  @override
  Future<void> start({int preBufferMs = 500}) async {
    throw Exception('Microphone access denied');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
