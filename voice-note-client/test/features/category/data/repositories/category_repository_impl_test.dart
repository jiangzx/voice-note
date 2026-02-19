import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/category/data/category_dao.dart';
import 'package:suikouji/features/category/data/repositories/category_repository_impl.dart';
import 'package:suikouji/features/category/domain/entities/category_entity.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';

void main() {
  late AppDatabase db;
  late CategoryRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final catDao = CategoryDao(db);
    final txDao = TransactionDao(db);
    repo = CategoryRepositoryImpl(catDao, txDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('CategoryRepositoryImpl', () {
    test('getVisible returns non-hidden categories by type', () async {
      final expense = await repo.getVisible('expense');
      expect(expense, isNotEmpty);
      expect(expense.every((c) => c.type == 'expense' && !c.isHidden), isTrue);
    });

    test('getAll includes hidden categories', () async {
      final all = await repo.getAll('expense');
      final visible = await repo.getVisible('expense');
      expect(all.length, greaterThanOrEqualTo(visible.length));
    });

    test('create adds a custom category', () async {
      final now = DateTime.now();
      await repo.create(
        CategoryEntity(
          id: 'custom-cat-1',
          name: '数码',
          type: 'expense',
          icon: 'material:devices',
          color: 'FF2196F3',
          isPreset: false,
          isHidden: false,
          sortOrder: 99,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final cat = await repo.getById('custom-cat-1');
      expect(cat, isNot(null));
      expect(cat!.name, '数码');
    });

    test('update modifies a category', () async {
      final now = DateTime.now();
      await repo.create(
        CategoryEntity(
          id: 'custom-cat-2',
          name: '外卖',
          type: 'expense',
          icon: 'material:delivery_dining',
          color: 'FFFF5722',
          isPreset: false,
          isHidden: false,
          sortOrder: 99,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final cat = await repo.getById('custom-cat-2');
      await repo.update(cat!.copyWith(name: '外卖配送'));
      final updated = await repo.getById('custom-cat-2');
      expect(updated!.name, '外卖配送');
    });

    test(
      'delete hard-deletes category with no transaction references',
      () async {
        final now = DateTime.now();
        await repo.create(
          CategoryEntity(
            id: 'del-cat-1',
            name: '临时',
            type: 'expense',
            icon: 'material:category',
            color: 'FF9E9E9E',
            isPreset: false,
            isHidden: false,
            sortOrder: 99,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repo.delete('del-cat-1');
        final result = await repo.getById('del-cat-1');
        expect(result, equals(null));
      },
    );

    test(
      'delete soft-deletes (hides) category with transaction references',
      () async {
        final now = DateTime.now();
        await repo.create(
          CategoryEntity(
            id: 'ref-cat-1',
            name: '有引用',
            type: 'expense',
            icon: 'material:category',
            color: 'FF9E9E9E',
            isPreset: false,
            isHidden: false,
            sortOrder: 99,
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Insert a transaction referencing this category
        final defaultAccount = await db.select(db.accounts).getSingle();
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: 'tx-ref-1',
                type: 'expense',
                amount: 10,
                date: now,
                categoryId: const drift.Value('ref-cat-1'),
                accountId: defaultAccount.id,
              ),
            );

        await repo.delete('ref-cat-1');
        final result = await repo.getById('ref-cat-1');
        expect(result, isNot(null));
        expect(result!.isHidden, isTrue);
      },
    );

    test('cannot delete preset category', () async {
      final presets = await repo.getAll('expense');
      final preset = presets.firstWhere((c) => c.isPreset);
      expect(() => repo.delete(preset.id), throwsA(isA<StateError>()));
    });

    test('reorder updates sort_order', () async {
      final cats = await repo.getVisible('expense');
      final ids = cats.map((c) => c.id).toList().reversed.toList();
      await repo.reorder(ids);

      final reordered = await repo.getVisible('expense');
      for (var i = 0; i < ids.length; i++) {
        final cat = reordered.firstWhere((c) => c.id == ids[i]);
        expect(cat.sortOrder, i);
      }
    });

    test('getRecentlyUsed returns empty when no transactions', () async {
      final recent = await repo.getRecentlyUsed();
      expect(recent, isEmpty);
    });
  });
}
