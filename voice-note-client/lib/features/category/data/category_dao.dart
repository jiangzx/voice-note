import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<List<Category>> getAll() => select(categories).get();

  Future<List<Category>> getByType(String type) =>
      (select(categories)..where((c) => c.type.equals(type))).get();

  Future<List<Category>> getVisible(String type) => (select(
    categories,
  )..where((c) => c.type.equals(type) & c.isHidden.equals(false))).get();

  Stream<List<Category>> watchVisible(String type) =>
      (select(categories)
            ..where((c) => c.type.equals(type) & c.isHidden.equals(false))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();

  Future<Category?> getById(String id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<bool> updateCategory(CategoriesCompanion entry) =>
      update(categories).replace(entry);

  Future<int> deleteById(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  Future<void> hide(String id) =>
      (update(categories)..where((c) => c.id.equals(id))).write(
        const CategoriesCompanion(isHidden: Value(true)),
      );

  Future<void> unhide(String id) =>
      (update(categories)..where((c) => c.id.equals(id))).write(
        const CategoriesCompanion(isHidden: Value(false)),
      );

  Future<void> updateSortOrders(Map<String, int> idToOrder) async {
    await batch((b) {
      for (final entry in idToOrder.entries) {
        b.update(
          categories,
          CategoriesCompanion(sortOrder: Value(entry.value)),
          where: (c) => c.id.equals(entry.key),
        );
      }
    });
  }

  Future<int> countTransactionsForCategory(String categoryId) async {
    final query = db.select(db.transactions)
      ..where((t) => t.categoryId.equals(categoryId));
    final results = await query.get();
    return results.length;
  }
}
