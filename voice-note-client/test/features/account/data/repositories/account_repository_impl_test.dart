import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/account/data/account_dao.dart';
import 'package:suikouji/features/account/data/repositories/account_repository_impl.dart';
import 'package:suikouji/features/account/domain/entities/account_entity.dart';

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final dao = AccountDao(db);
    final prefs = await SharedPreferences.getInstance();
    repo = AccountRepositoryImpl(dao, prefs);
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountRepositoryImpl', () {
    test('getDefault returns the preset 钱包 account', () async {
      final account = await repo.getDefault();
      expect(account, isNotNull);
      expect(account!.name, '钱包');
      expect(account.isPreset, isTrue);
    });

    test('getAll returns seeded accounts', () async {
      final accounts = await repo.getAll();
      expect(accounts.length, 1);
    });

    test('create adds a new account', () async {
      final now = DateTime.now();
      await repo.create(
        AccountEntity(
          id: 'custom-1',
          name: '招商银行',
          type: 'bank_card',
          icon: 'material:account_balance',
          color: 'FF1E88E5',
          isPreset: false,
          sortOrder: 1,
          initialBalance: 0,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final accounts = await repo.getAll();
      expect(accounts.length, 2);
    });

    test('archive sets isArchived and excludes from active list', () async {
      final now = DateTime.now();
      await repo.create(
        AccountEntity(
          id: 'custom-2',
          name: '微信',
          type: 'wechat',
          icon: 'material:account_balance_wallet',
          color: 'FF4CAF50',
          isPreset: false,
          sortOrder: 2,
          initialBalance: 0,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.archive('custom-2');
      final active = await repo.getActive();
      expect(active.any((a) => a.id == 'custom-2'), isFalse);
    });

    test('cannot delete preset account', () async {
      final preset = await repo.getDefault();
      expect(() => repo.deleteById(preset!.id), throwsA(isA<StateError>()));
    });

    test('cannot archive preset account', () async {
      final preset = await repo.getDefault();
      expect(() => repo.archive(preset!.id), throwsA(isA<StateError>()));
    });

    test('multi account toggle persists across reads', () async {
      expect(await repo.isMultiAccountEnabled(), isFalse);
      await repo.setMultiAccountEnabled(enabled: true);
      expect(await repo.isMultiAccountEnabled(), isTrue);
      await repo.setMultiAccountEnabled(enabled: false);
      expect(await repo.isMultiAccountEnabled(), isFalse);
    });
  });
}
