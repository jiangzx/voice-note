import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/nlp/amount_extractor.dart';

void main() {
  group('AmountExtractor', () {
    test('extracts plain number', () {
      expect(AmountExtractor.extract('花了35'), 35.0);
    });

    test('extracts decimal number', () {
      expect(AmountExtractor.extract('花了28.5'), 28.5);
    });

    test('extracts amount with 块', () {
      expect(AmountExtractor.extract('午饭35块'), 35.0);
    });

    test('extracts amount with 块钱', () {
      expect(AmountExtractor.extract('打车35块钱'), 35.0);
    });

    test('extracts amount with 元', () {
      expect(AmountExtractor.extract('付了100元'), 100.0);
    });

    test('extracts X块Y pattern', () {
      expect(AmountExtractor.extract('花了28块5'), 28.5);
    });

    test('extracts ¥ prefix', () {
      expect(AmountExtractor.extract('¥188'), 188.0);
    });

    test('extracts ￥ prefix', () {
      expect(AmountExtractor.extract('￥35.5'), 35.5);
    });

    test('returns null for no amount', () {
      expect(AmountExtractor.extract('今天午饭'), isNull);
    });

    test('extracts amount after cost verb', () {
      expect(AmountExtractor.extract('消费了200'), 200.0);
    });
  });

  group('Chinese numerals', () {
    test('single digit: 五块', () {
      expect(AmountExtractor.extract('咖啡五块'), 5.0);
    });

    test('十: 十块', () {
      expect(AmountExtractor.extract('花了十块'), 10.0);
    });

    test('十五: 十五元', () {
      expect(AmountExtractor.extract('地铁十五元'), 15.0);
    });

    test('三十五: 三十五块', () {
      expect(AmountExtractor.extract('午饭三十五块'), 35.0);
    });

    test('一百二十: 一百二十元', () {
      expect(AmountExtractor.extract('买书一百二十元'), 120.0);
    });

    test('两百: 两百块', () {
      expect(AmountExtractor.extract('花了两百块'), 200.0);
    });

    test('implied unit: 两千五 → 2500', () {
      expect(AmountExtractor.extract('交了两千五块钱'), 2500.0);
    });

    test('三百: 三百元', () {
      expect(AmountExtractor.extract('充值三百元'), 300.0);
    });

    test('cost verb: 花了三十五', () {
      expect(AmountExtractor.extract('花了三十五'), 35.0);
    });

    test('Arabic digits take priority over Chinese', () {
      expect(AmountExtractor.extract('花了35块'), 35.0);
    });

    test('chineseToNumber comprehensive', () {
      expect(AmountExtractor.chineseToNumber('零'), null);
      expect(AmountExtractor.chineseToNumber('一'), 1);
      expect(AmountExtractor.chineseToNumber('十'), 10);
      expect(AmountExtractor.chineseToNumber('十五'), 15);
      expect(AmountExtractor.chineseToNumber('二十'), 20);
      expect(AmountExtractor.chineseToNumber('三十五'), 35);
      expect(AmountExtractor.chineseToNumber('一百'), 100);
      expect(AmountExtractor.chineseToNumber('一百二十'), 120);
      expect(AmountExtractor.chineseToNumber('两百'), 200);
      expect(AmountExtractor.chineseToNumber('三百'), 300);
      expect(AmountExtractor.chineseToNumber('一千'), 1000);
      expect(AmountExtractor.chineseToNumber('两千五'), 2500);
      expect(AmountExtractor.chineseToNumber('一万'), 10000);
      expect(AmountExtractor.chineseToNumber('一万五千'), 15000);
    });
  });
}
