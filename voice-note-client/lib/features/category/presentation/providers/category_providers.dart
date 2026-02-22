import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/database_provider.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/services/time_period_recommendation_service.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';

part 'category_providers.g.dart';

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) {
  final catDao = ref.watch(categoryDaoProvider);
  final txDao = ref.watch(transactionDaoProvider);
  return CategoryRepositoryImpl(catDao, txDao);
}

@riverpod
Future<List<CategoryEntity>> visibleCategories(Ref ref, String type) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getVisible(type);
}

/// Preset category id for transfer: 转出 (outbound) or 转入 (inbound). Used to default selection when creating a transfer.
@riverpod
Future<String?> transferDefaultCategoryId(
  Ref ref,
  TransferDirection direction,
) async {
  final type = direction == TransferDirection.outbound ? 'expense' : 'income';
  final name = direction == TransferDirection.outbound ? '转出' : '转入';
  final list = await ref.watch(visibleCategoriesProvider(type).future);
  final found = list.where((c) => c.name == name).toList();
  return found.isEmpty ? null : found.first.id;
}

@riverpod
Future<List<String>> recentCategories(Ref ref) async {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getRecentlyUsed();
}

@riverpod
List<String> recommendedCategoryNames(Ref ref) {
  const service = TimePeriodRecommendationService();
  return service.getRecommendedCategoryNames(DateTime.now());
}
