import '../entities/category_entity.dart';

/// Contract for category data access.
abstract class CategoryRepository {
  Future<List<CategoryEntity>> getVisible(String type);
  Future<List<CategoryEntity>> getAll(String type);
  Future<CategoryEntity?> getById(String id);
  Future<void> create(CategoryEntity category);
  Future<void> update(CategoryEntity category);

  /// Deletes if no transactions reference it; hides (soft-delete) otherwise.
  Future<void> delete(String id);

  Future<void> reorder(List<String> orderedIds);
  Future<List<String>> getRecentlyUsed({int limit = 3});
}
