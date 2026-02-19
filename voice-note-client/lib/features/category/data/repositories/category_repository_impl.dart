import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../transaction/data/transaction_dao.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../category_dao.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryDao _dao;
  final TransactionDao _txDao;

  const CategoryRepositoryImpl(this._dao, this._txDao);

  @override
  Future<List<CategoryEntity>> getVisible(String type) async {
    final rows = await _dao.getVisible(type);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<CategoryEntity>> getAll(String type) async {
    final rows = await _dao.getByType(type);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<CategoryEntity?> getById(String id) async {
    final row = await _dao.getById(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<void> create(CategoryEntity category) async {
    await _dao.insertCategory(_toCompanion(category));
  }

  @override
  Future<void> update(CategoryEntity category) async {
    final updated = category.copyWith(updatedAt: DateTime.now());
    await _dao.updateCategory(_toCompanion(updated));
  }

  @override
  Future<void> delete(String id) async {
    final existing = await _dao.getById(id);
    if (existing == null) return;
    if (existing.isPreset) {
      throw StateError('Cannot delete preset category');
    }

    final refCount = await _dao.countTransactionsForCategory(id);
    if (refCount > 0) {
      await _dao.hide(id);
    } else {
      await _dao.deleteById(id);
    }
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    final idToOrder = <String, int>{};
    for (var i = 0; i < orderedIds.length; i++) {
      idToOrder[orderedIds[i]] = i;
    }
    await _dao.updateSortOrders(idToOrder);
  }

  @override
  Future<List<String>> getRecentlyUsed({int limit = 3}) async {
    return _txDao.getRecentCategoryIds(limit);
  }

  // ── Mapping helpers ──

  CategoryEntity _toEntity(Category row) {
    return CategoryEntity(
      id: row.id,
      name: row.name,
      type: row.type,
      icon: row.icon,
      color: row.color,
      isPreset: row.isPreset,
      isHidden: row.isHidden,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  CategoriesCompanion _toCompanion(CategoryEntity e) {
    return CategoriesCompanion(
      id: Value(e.id),
      name: Value(e.name),
      type: Value(e.type),
      icon: Value(e.icon),
      color: Value(e.color),
      isPreset: Value(e.isPreset),
      isHidden: Value(e.isHidden),
      sortOrder: Value(e.sortOrder),
      createdAt: Value(e.createdAt),
      updatedAt: Value(e.updatedAt),
    );
  }
}
