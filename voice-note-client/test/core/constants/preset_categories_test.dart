import 'package:flutter_test/flutter_test.dart';
import 'package:voice_note_client/core/constants/preset_categories.dart';

void main() {
  group('preset_categories', () {
    test('expense presets include 转出', () {
      final names = presetExpenseCategories.map((c) => c.name).toList();
      expect(names, contains('转出'));
      expect(
        presetExpenseCategories.firstWhere((c) => c.name == '转出').type,
        'expense',
      );
      expect(
        presetExpenseCategories.firstWhere((c) => c.name == '转出').isHidden,
        false,
      );
    });

    test('income presets include 转入', () {
      final names = presetIncomeCategories.map((c) => c.name).toList();
      expect(names, contains('转入'));
      expect(
        presetIncomeCategories.firstWhere((c) => c.name == '转入').type,
        'income',
      );
    });

    test('allPresetCategories has 13 expense and 6 income (19 total)', () {
      final expense = allPresetCategories.where((c) => c.type == 'expense');
      final income = allPresetCategories.where((c) => c.type == 'income');
      expect(expense.length, 13);
      expect(income.length, 6);
      expect(allPresetCategories.length, 19);
    });
  });
}
