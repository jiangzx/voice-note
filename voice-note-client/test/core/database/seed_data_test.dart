import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('seed data', () {
    test('creates exactly 17 preset categories', () async {
      final categories = await db.select(db.categories).get();
      expect(categories.length, 17);
    });

    test('creates 12 expense and 5 income categories', () async {
      final categories = await db.select(db.categories).get();
      final expense = categories.where((c) => c.type == 'expense');
      final income = categories.where((c) => c.type == 'income');
      expect(expense.length, 12);
      expect(income.length, 5);
    });

    test('marks 宠物 and 旅行 as hidden', () async {
      final categories = await db.select(db.categories).get();
      final hidden = categories.where((c) => c.isHidden).toList();
      expect(hidden.length, 2);
      final names = hidden.map((c) => c.name).toSet();
      expect(names, containsAll(['宠物', '旅行']));
    });

    test('all preset categories have isPreset=true', () async {
      final categories = await db.select(db.categories).get();
      for (final c in categories) {
        expect(c.isPreset, isTrue, reason: '${c.name} should be preset');
      }
    });

    test('creates exactly 1 default account', () async {
      final accounts = await db.select(db.accounts).get();
      expect(accounts.length, 1);
    });

    test('default account is named 钱包 with correct attributes', () async {
      final accounts = await db.select(db.accounts).get();
      final wallet = accounts.first;
      expect(wallet.name, '钱包');
      expect(wallet.type, 'cash');
      expect(wallet.isPreset, isTrue);
      expect(wallet.isArchived, isFalse);
      expect(wallet.initialBalance, 0.0);
    });

    test('all records have syncStatus=local and remoteId=null', () async {
      final categories = await db.select(db.categories).get();
      final accounts = await db.select(db.accounts).get();
      for (final c in categories) {
        expect(c.syncStatus, 'local');
        expect(c.remoteId, isNull);
      }
      for (final a in accounts) {
        expect(a.syncStatus, 'local');
        expect(a.remoteId, isNull);
      }
    });
  });
}
