import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/account/data/account_dao.dart';
import 'package:suikouji/features/category/data/category_dao.dart';
import 'package:suikouji/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';
import 'package:suikouji/features/voice/data/voice_transaction_service.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';

void main() {
  late AppDatabase db;
  late VoiceTransactionService service;
  late TransactionDao txDao;
  late AccountDao accountDao;
  late CategoryDao categoryDao;

  setUp(() async {
    // In-memory DB automatically seeds preset accounts & categories
    db = AppDatabase(NativeDatabase.memory());

    txDao = TransactionDao(db);
    accountDao = AccountDao(db);
    categoryDao = CategoryDao(db);
    final repo = TransactionRepositoryImpl(txDao, accountDao);

    service = VoiceTransactionService(
      transactionRepo: repo,
      categoryDao: categoryDao,
      accountDao: accountDao,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('save', () {
    test('saves expense with matched category', () async {
      const result = ParseResult(
        amount: 42.5,
        category: '餐饮',
        description: '午餐',
        type: 'EXPENSE',
        date: '2026-02-17',
        confidence: 0.8,
        source: ParseSource.local,
      );

      final entity = await service.save(result);

      expect(entity.amount, 42.5);
      expect(entity.categoryId, isNotNull);
      expect(entity.description, '午餐');
      expect(entity.type.name, 'expense');
      expect(entity.date.year, 2026);
      expect(entity.date.month, 2);
      expect(entity.date.day, 17);

      // Verify persisted in DB
      final rows = await txDao.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.amount, 42.5);
    });

    test('saves income with correct type mapping', () async {
      const result = ParseResult(
        amount: 5000.0,
        category: '工资',
        type: 'INCOME',
        confidence: 0.9,
        source: ParseSource.llm,
      );

      final entity = await service.save(result);

      expect(entity.type.name, 'income');
      expect(entity.categoryId, isNotNull);

      // Verify the matched category is actually "工资"
      final cat = await categoryDao.getById(entity.categoryId!);
      expect(cat?.name, '工资');
    });

    test('uses default account when no account specified', () async {
      const result = ParseResult(
        amount: 10.0,
        category: '交通',
        confidence: 0.8,
        source: ParseSource.local,
      );

      final entity = await service.save(result);
      final defaultAccount = await accountDao.getDefault();
      expect(entity.accountId, defaultAccount!.id);
    });

    test('uses today when no date specified', () async {
      const result = ParseResult(
        amount: 20.0,
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );

      final entity = await service.save(result);
      final today = DateTime.now();
      expect(entity.date.year, today.year);
      expect(entity.date.month, today.month);
      expect(entity.date.day, today.day);
    });

    test('throws VoiceSaveException on null amount', () async {
      const result = ParseResult(
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );

      expect(
        () => service.save(result),
        throwsA(isA<VoiceSaveException>()),
      );
    });

    test('throws VoiceSaveException on zero amount', () async {
      const result = ParseResult(
        amount: 0,
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );

      expect(
        () => service.save(result),
        throwsA(isA<VoiceSaveException>()),
      );
    });

    test('resolves category by partial match', () async {
      const result = ParseResult(
        amount: 15.0,
        category: '餐饮美食',
        confidence: 0.7,
        source: ParseSource.local,
      );

      final entity = await service.save(result);
      expect(entity.categoryId, isNotNull);

      final cat = await categoryDao.getById(entity.categoryId!);
      expect(cat?.name, '餐饮');
    });

    test('generates unique IDs for multiple saves', () async {
      const result = ParseResult(
        amount: 10.0,
        category: '餐饮',
        confidence: 0.8,
        source: ParseSource.local,
      );

      final e1 = await service.save(result);
      final e2 = await service.save(result);

      expect(e1.id, isNot(e2.id));

      final rows = await txDao.getAll();
      expect(rows, hasLength(2));
    });

    test('defaults type to expense for unknown type string', () async {
      const result = ParseResult(
        amount: 30.0,
        category: '购物',
        type: 'UNKNOWN',
        confidence: 0.5,
        source: ParseSource.local,
      );

      final entity = await service.save(result);
      expect(entity.type, TransactionType.expense);
    });

    test('resolves medical category from seed data', () async {
      const result = ParseResult(
        amount: 200.0,
        category: '医疗',
        confidence: 0.9,
        source: ParseSource.local,
      );

      final entity = await service.save(result);
      expect(entity.categoryId, isNotNull);

      final cat = await categoryDao.getById(entity.categoryId!);
      expect(cat?.name, '医疗');
    });

    test('saves transfer with 转出/转入 category by direction', () async {
      const resultOut = ParseResult(
        amount: 500.0,
        type: 'TRANSFER',
        transferDirection: 'out',
        confidence: 0.9,
        source: ParseSource.llm,
      );
      final entityOut = await service.save(resultOut);
      expect(entityOut.type, TransactionType.transfer);
      expect(entityOut.categoryId, isNotNull);
      final catOut = await categoryDao.getById(entityOut.categoryId!);
      expect(catOut?.name, '转出');

      const resultIn = ParseResult(
        amount: 200.0,
        type: 'TRANSFER',
        transferDirection: 'in',
        confidence: 0.9,
        source: ParseSource.llm,
      );
      final entityIn = await service.save(resultIn);
      expect(entityIn.categoryId, isNotNull);
      final catIn = await categoryDao.getById(entityIn.categoryId!);
      expect(catIn?.name, '转入');
    });
  });

  group('saveBatch', () {
    test('saves multiple items atomically', () async {
      const results = [
        ParseResult(
          amount: 10.0,
          category: '餐饮',
          description: '早餐',
          date: '2026-02-19',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
        ParseResult(
          amount: 50.0,
          category: '交通',
          description: '地铁',
          date: '2026-02-19',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
        ParseResult(
          amount: 3000.0,
          category: '工资',
          type: 'INCOME',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
      ];

      final entities = await service.saveBatch(results);

      expect(entities, hasLength(3));
      expect(entities[0].amount, 10.0);
      expect(entities[0].description, '早餐');
      expect(entities[1].amount, 50.0);
      expect(entities[2].type, TransactionType.income);

      final rows = await txDao.getAll();
      expect(rows, hasLength(3));
    });

    test('returns empty list for empty input', () async {
      final entities = await service.saveBatch([]);
      expect(entities, isEmpty);

      final rows = await txDao.getAll();
      expect(rows, isEmpty);
    });

    test('rolls back all when one item has invalid amount', () async {
      const results = [
        ParseResult(
          amount: 25.0,
          category: '餐饮',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
        ParseResult(
          amount: 0,
          category: '交通',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
      ];

      expect(
        () => service.saveBatch(results),
        throwsA(isA<VoiceSaveException>()),
      );

      final rows = await txDao.getAll();
      expect(rows, isEmpty, reason: 'No rows should persist after rollback');
    });

    test('rolls back all when one item has null amount', () async {
      const results = [
        ParseResult(
          amount: 100.0,
          category: '餐饮',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
        ParseResult(
          category: '购物',
          confidence: 0.5,
          source: ParseSource.llm,
        ),
      ];

      expect(
        () => service.saveBatch(results),
        throwsA(isA<VoiceSaveException>()),
      );

      final rows = await txDao.getAll();
      expect(rows, isEmpty, reason: 'No rows should persist after rollback');
    });

    test('generates unique IDs across batch', () async {
      const results = [
        ParseResult(
          amount: 10.0,
          category: '餐饮',
          confidence: 0.9,
          source: ParseSource.local,
        ),
        ParseResult(
          amount: 20.0,
          category: '餐饮',
          confidence: 0.9,
          source: ParseSource.local,
        ),
      ];

      final entities = await service.saveBatch(results);
      expect(entities[0].id, isNot(entities[1].id));
    });

    test('single-item batch works like save', () async {
      const results = [
        ParseResult(
          amount: 42.0,
          category: '餐饮',
          description: '午饭',
          confidence: 0.9,
          source: ParseSource.llm,
        ),
      ];

      final entities = await service.saveBatch(results);
      expect(entities, hasLength(1));
      expect(entities.first.amount, 42.0);

      final rows = await txDao.getAll();
      expect(rows, hasLength(1));
    });
  });
}
