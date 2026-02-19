import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/database_provider.dart';

/// Provides an ordered list of quick-input suggestion words.
///
/// Strategy:
/// 1. Load recent transactions (up to 200)
/// 2. Count frequency of category names and short descriptions (≤4 chars)
/// 3. Sort by frequency descending, deduplicate
/// 4. Fill remaining slots with default suggestions
final quickSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final txDao = ref.watch(transactionDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);

  final recentTx = await txDao.getRecent(200);
  final allCategories = await categoryDao.getAll();

  // Map category ID → name
  final categoryNames = {
    for (final c in allCategories) c.id: c.name,
  };

  // Count frequencies from history
  final freq = <String, int>{};
  for (final tx in recentTx) {
    // Count category names
    if (tx.categoryId != null) {
      final name = categoryNames[tx.categoryId];
      if (name != null && name.length <= 4) {
        freq[name] = (freq[name] ?? 0) + 1;
      }
    }

    // Count short description keywords
    if (tx.description != null && tx.description!.length <= 4 && tx.description!.isNotEmpty) {
      freq[tx.description!] = (freq[tx.description!] ?? 0) + 1;
    }
  }

  // Sort by frequency descending
  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final result = sorted.map((e) => e.key).toList();

  // Fill with defaults if needed
  for (final d in _defaults) {
    if (result.length >= _maxSuggestions) break;
    if (!result.contains(d)) result.add(d);
  }

  return result.take(_maxSuggestions).toList();
});

const _maxSuggestions = 16;

const _defaults = [
  '午饭',
  '晚饭',
  '早餐',
  '打车',
  '地铁',
  '咖啡',
  '奶茶',
  '水果',
  '超市',
  '外卖',
  '话费',
  '加油',
  '停车',
  '快递',
  '工资',
  '红包',
];
