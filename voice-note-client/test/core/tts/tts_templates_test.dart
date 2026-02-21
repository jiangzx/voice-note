import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/tts/tts_templates.dart';

void main() {
  group('TtsTemplates', () {
    test('welcome returns greeting', () {
      expect(TtsTemplates.welcome(), '你好，想记点什么？');
    });

    test('confirm formats expense correctly', () {
      final text = TtsTemplates.confirm(
        category: '餐饮',
        type: 'expense',
        amount: 35,
      );
      expect(text, '识别到餐饮支出35元，确认吗？');
    });

    test('confirm formats income correctly', () {
      final text = TtsTemplates.confirm(
        category: '工资',
        type: 'income',
        amount: 5000,
      );
      expect(text, '识别到工资收入5000元，确认吗？');
    });

    test('confirm formats transfer correctly', () {
      final text = TtsTemplates.confirm(
        category: '转账',
        type: 'transfer',
        amount: 100,
      );
      expect(text, '识别到转账转账100元，确认吗？');
    });

    test('confirm formats decimal amount', () {
      final text = TtsTemplates.confirm(
        category: '餐饮',
        type: 'expense',
        amount: 35.50,
      );
      expect(text, '识别到餐饮支出35.50元，确认吗？');
    });

    test('confirm handles unknown type as expense', () {
      final text = TtsTemplates.confirm(
        category: '餐饮',
        type: 'unknown',
        amount: 10,
      );
      expect(text, '识别到餐饮支出10元，确认吗？');
    });

    test('saved returns continuation prompt', () {
      expect(TtsTemplates.saved(), '记好了，还有吗？');
    });

    test('timeout returns warning', () {
      expect(TtsTemplates.timeout(),
          '还在吗？暂时不用的话我会先休息哦，30秒后自动退出');
    });

    test('sessionEnd formats integer total', () {
      final text = TtsTemplates.sessionEnd(count: 3, total: 100);
      expect(text, '本次记了3笔，共100元，拜拜');
    });

    test('sessionEnd formats decimal total', () {
      final text = TtsTemplates.sessionEnd(count: 2, total: 88.50);
      expect(text, '本次记了2笔，共88.50元，拜拜');
    });
  });

  group('Correction templates', () {
    test('correctionLoading', () {
      expect(TtsTemplates.correctionLoading(), '好的，正在修改');
    });

    test('correctionConfirm', () {
      expect(TtsTemplates.correctionConfirm(), '已修改，请确认');
    });

    test('correctionFailed', () {
      expect(TtsTemplates.correctionFailed(), '没听清要改什么，请再说一次');
    });
  });

  group('Batch templates', () {
    test('batchConfirmation with 2 items', () {
      final text = TtsTemplates.batchConfirmation([
        (category: '餐饮', type: 'expense', amount: 35.0),
        (category: '交通', type: 'expense', amount: 10.0),
      ]);
      expect(
        text,
        '识别到2笔交易：第1笔，餐饮支出35元；第2笔，交通支出10元。确认吗？',
      );
    });

    test('batchConfirmation with income item', () {
      final text = TtsTemplates.batchConfirmation([
        (category: '餐饮', type: 'expense', amount: 20.0),
        (category: '工资', type: 'income', amount: 5000.0),
      ]);
      expect(text, contains('收入5000元'));
    });

    test('batchConfirmation handles null category and amount', () {
      final text = TtsTemplates.batchConfirmation([
        (category: null, type: 'expense', amount: null),
        (category: '餐饮', type: 'expense', amount: 10.0),
      ]);
      expect(text, contains('第1笔，支出'));
      expect(text, contains('第2笔，餐饮支出10元'));
    });

    test('batchSummary', () {
      final text = TtsTemplates.batchSummary(count: 7, total: 1234.50);
      expect(text, '识别到7笔交易，合计1234.50元，请逐笔确认');
    });

    test('batchSummary with integer total', () {
      final text = TtsTemplates.batchSummary(count: 6, total: 500);
      expect(text, '识别到6笔交易，合计500元，请逐笔确认');
    });

    test('batchSaved', () {
      expect(TtsTemplates.batchSaved(count: 3), '已保存3笔交易');
    });

    test('batchItemCancelled', () {
      expect(TtsTemplates.batchItemCancelled(displayIndex: 2), '第2笔已取消');
    });

    test('batchTargetedCorrection', () {
      expect(
        TtsTemplates.batchTargetedCorrection(displayIndex: 1),
        '第1笔已修改',
      );
    });

    test('batchAppended', () {
      expect(
        TtsTemplates.batchAppended(displayIndex: 4),
        '好的，已追加第4笔',
      );
    });

    test('batchLimitReached', () {
      expect(TtsTemplates.batchLimitReached(), '最多只能记10笔，请先确认当前交易');
    });
  });
}
