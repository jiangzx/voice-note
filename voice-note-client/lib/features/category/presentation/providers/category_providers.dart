import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/database_provider.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/services/time_period_recommendation_service.dart';

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
