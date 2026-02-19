import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';
import 'package:suikouji/features/voice/domain/voice_correction_handler.dart';

void main() {
  late VoiceCorrectionHandler handler;

  setUp(() {
    handler = VoiceCorrectionHandler();
  });

  group('classify', () {
    group('cancel intent', () {
      test('identifies cancel keywords', () {
        expect(handler.classify('不要了'), CorrectionIntent.cancel);
        expect(handler.classify('取消'), CorrectionIntent.cancel);
        expect(handler.classify('算了不记了'), CorrectionIntent.cancel);
        expect(handler.classify('删掉'), CorrectionIntent.cancel);
      });
    });

    group('confirm intent', () {
      test('identifies confirm keywords', () {
        expect(handler.classify('对的'), CorrectionIntent.confirm);
        expect(handler.classify('嗯对'), CorrectionIntent.confirm);
        expect(handler.classify('确认'), CorrectionIntent.confirm);
        expect(handler.classify('没错'), CorrectionIntent.confirm);
        expect(handler.classify('可以'), CorrectionIntent.confirm);
      });
    });

    group('correction intent — original prefixes', () {
      test('identifies existing correction prefixes', () {
        expect(handler.classify('不对是45'), CorrectionIntent.correction);
        expect(handler.classify('金额改成50'), CorrectionIntent.correction);
        expect(handler.classify('分类改成购物'), CorrectionIntent.correction);
        expect(handler.classify('改一下金额'), CorrectionIntent.correction);
        expect(handler.classify('错了应该是50'), CorrectionIntent.correction);
      });
    });

    group('correction intent — new prefixes', () {
      test('identifies 修改为', () {
        expect(handler.classify('修改为50元'), CorrectionIntent.correction);
      });

      test('identifies 改为', () {
        expect(handler.classify('改为交通'), CorrectionIntent.correction);
      });

      test('identifies 应该是', () {
        expect(handler.classify('应该是收入'), CorrectionIntent.correction);
      });

      test('identifies 不是', () {
        expect(handler.classify('不是支出是收入'), CorrectionIntent.correction);
      });

      test('identifies 搞错了', () {
        expect(handler.classify('搞错了'), CorrectionIntent.correction);
      });

      test('identifies 弄错了', () {
        expect(handler.classify('弄错了应该是50'), CorrectionIntent.correction);
      });
    });

    group('correction intent — field keywords', () {
      test('identifies 金额', () {
        expect(handler.classify('金额不对'), CorrectionIntent.correction);
      });

      test('identifies 日期', () {
        expect(handler.classify('日期改成昨天'), CorrectionIntent.correction);
      });

      test('identifies 收入 as correction', () {
        expect(handler.classify('收入不是支出'), CorrectionIntent.correction);
      });

      test('identifies 支出 as correction', () {
        expect(handler.classify('支出而不是收入'), CorrectionIntent.correction);
      });
    });

    group('indexed item intents', () {
      test('identifies confirmItem', () {
        expect(handler.classify('确认第1笔'), CorrectionIntent.confirmItem);
        expect(handler.classify('确认第3笔'), CorrectionIntent.confirmItem);
        expect(handler.classify('确认第10笔'), CorrectionIntent.confirmItem);
      });

      test('identifies cancelItem with 删掉', () {
        expect(handler.classify('删掉第1笔'), CorrectionIntent.cancelItem);
        expect(handler.classify('删掉第2笔'), CorrectionIntent.cancelItem);
      });

      test('identifies cancelItem with 取消', () {
        expect(handler.classify('取消第3笔'), CorrectionIntent.cancelItem);
      });

      test('identifies cancelItem with 去掉', () {
        expect(handler.classify('去掉第2笔'), CorrectionIntent.cancelItem);
      });

      test('indexed patterns take priority over plain cancel/confirm', () {
        // "确认第1笔" should be confirmItem, not confirm
        expect(handler.classify('确认第1笔'), CorrectionIntent.confirmItem);
        // "取消第2笔" should be cancelItem, not cancel
        expect(handler.classify('取消第2笔'), CorrectionIntent.cancelItem);
      });
    });

    group('exit intent', () {
      test('identifies exit keywords', () {
        expect(handler.classify('没了'), CorrectionIntent.exit);
        expect(handler.classify('拜拜'), CorrectionIntent.exit);
        expect(handler.classify('退出'), CorrectionIntent.exit);
      });
    });

    group('continue intent', () {
      test('identifies continue keywords', () {
        expect(handler.classify('还有'), CorrectionIntent.continueRecording);
        expect(handler.classify('继续'), CorrectionIntent.continueRecording);
        expect(handler.classify('再记一笔'), CorrectionIntent.continueRecording);
      });
    });

    test('defaults to newInput for unknown text', () {
      expect(handler.classify('午饭35'), CorrectionIntent.newInput);
      expect(handler.classify('买了个苹果'), CorrectionIntent.newInput);
    });

    group('priority order', () {
      test('cancel beats confirmation', () {
        // "不要了" contains cancel, even if "了" is not confirm
        expect(handler.classify('不要了'), CorrectionIntent.cancel);
      });

      test('correction "不对" beats confirmation "对"', () {
        expect(handler.classify('不对'), CorrectionIntent.correction);
      });

      test('indexed cancel beats plain cancel', () {
        expect(handler.classify('取消第1笔'), CorrectionIntent.cancelItem);
      });
    });
  });

  group('extractItemIndex', () {
    test('extracts 1-based index from confirm pattern', () {
      expect(handler.extractItemIndex('确认第1笔'), 1);
      expect(handler.extractItemIndex('确认第3笔'), 3);
    });

    test('extracts 1-based index from cancel pattern', () {
      expect(handler.extractItemIndex('删掉第2笔'), 2);
      expect(handler.extractItemIndex('取消第5笔'), 5);
      expect(handler.extractItemIndex('去掉第1笔'), 1);
    });

    test('returns null for non-indexed text', () {
      expect(handler.extractItemIndex('确认'), isNull);
      expect(handler.extractItemIndex('取消'), isNull);
      expect(handler.extractItemIndex('改成50'), isNull);
    });
  });

  group('applyCorrection', () {
    const current = ParseResult(
      amount: 35,
      category: '餐饮',
      type: 'EXPENSE',
      confidence: 0.9,
      source: ParseSource.local,
    );

    test('corrects amount', () {
      final updated = handler.applyCorrection('是45', current);
      expect(updated?.amount, 45.0);
      expect(updated?.category, '餐饮');
    });

    test('corrects category', () {
      final updated = handler.applyCorrection('改成交通打车', current);
      expect(updated?.category, '交通');
      expect(updated?.amount, 35);
    });

    test('returns null for unrecognized correction', () {
      final updated = handler.applyCorrection('嗯嗯嗯', current);
      expect(updated, isNull);
    });

    group('type correction', () {
      test('corrects EXPENSE to INCOME', () {
        final updated = handler.applyCorrection('应该是收入', current);
        expect(updated?.type, 'INCOME');
        expect(updated?.amount, 35);
        expect(updated?.category, '餐饮');
      });

      test('corrects INCOME to EXPENSE', () {
        const incomeResult = ParseResult(
          amount: 50,
          category: '红包',
          type: 'INCOME',
          confidence: 0.9,
          source: ParseSource.llm,
        );
        final updated = handler.applyCorrection('是支出', incomeResult);
        expect(updated?.type, 'EXPENSE');
      });

      test('returns null when type already matches (收入)', () {
        const incomeResult = ParseResult(
          amount: 50,
          category: '红包',
          type: 'INCOME',
          confidence: 0.9,
          source: ParseSource.llm,
        );
        final updated = handler.applyCorrection('收入', incomeResult);
        expect(updated, isNull);
      });

      test('returns null when type already matches (支出)', () {
        final updated = handler.applyCorrection('支出', current);
        expect(updated, isNull);
      });

      test('type correction takes priority over amount', () {
        // "收入50" should correct type, not amount
        final updated = handler.applyCorrection('收入50', current);
        expect(updated?.type, 'INCOME');
      });
    });
  });
}
