import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/category/data/category_dao.dart';
import 'package:suikouji/features/category/data/repositories/category_repository_impl.dart';
import 'package:suikouji/features/category/presentation/providers/category_providers.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final catDao = CategoryDao(db);
    final txDao = TransactionDao(db);
    final repo = CategoryRepositoryImpl(catDao, txDao);

    container = ProviderContainer(
      overrides: [categoryRepositoryProvider.overrideWith((_) => repo)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('visibleCategoriesProvider', () {
    test('returns seeded expense categories', () async {
      final cats = await container.read(
        visibleCategoriesProvider('expense').future,
      );
      expect(cats, isNotEmpty);
      expect(cats.every((c) => c.type == 'expense'), isTrue);
    });

    test('returns seeded income categories', () async {
      final cats = await container.read(
        visibleCategoriesProvider('income').future,
      );
      expect(cats, isNotEmpty);
      expect(cats.every((c) => c.type == 'income'), isTrue);
    });
  });

  group('recentCategoriesProvider', () {
    test('returns empty list with no transactions', () async {
      final recent = await container.read(recentCategoriesProvider.future);
      expect(recent, isEmpty);
    });
  });

  group('recommendedCategoryNamesProvider', () {
    test('returns a list (content depends on current time)', () {
      final names = container.read(recommendedCategoryNamesProvider);
      expect(names, isA<List<String>>());
    });
  });
}
