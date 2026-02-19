import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/nlp/category_matcher.dart';

void main() {
  group('CategoryMatcher', () {
    late CategoryMatcher matcher;

    setUp(() {
      matcher = CategoryMatcher();
    });

    test('matches 打车 → 交通', () {
      expect(matcher.match('打车28'), '交通');
    });

    test('matches 午饭 → 餐饮', () {
      expect(matcher.match('午饭花了35'), '餐饮');
    });

    test('matches 外卖 → 餐饮', () {
      expect(matcher.match('叫了个外卖'), '餐饮');
    });

    test('matches 电费 → 账单', () {
      expect(matcher.match('交电费200'), '账单');
    });

    test('matches 电影 → 娱乐', () {
      expect(matcher.match('看电影'), '娱乐');
    });

    test('matches 房租 → 住房', () {
      expect(matcher.match('交房租'), '住房');
    });

    test('matches 工资 → 工资 (income)', () {
      expect(matcher.match('发工资了'), '工资');
    });

    test('returns null for unmatched text', () {
      expect(matcher.match('做了件事'), isNull);
    });

    test('custom categories are matched', () {
      final custom = CategoryMatcher(customCategories: ['学习资料', '宠物用品']);
      expect(custom.match('买了学习资料'), '学习资料');
      expect(custom.match('宠物用品花了50'), '宠物用品');
    });

    test('prefers longer keyword match', () {
      // 共享单车 (4 chars) should match before 骑车 (2 chars)
      expect(matcher.match('骑共享单车'), '交通');
    });
  });
}
