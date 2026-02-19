import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/account/data/account_dao.dart';
import 'package:suikouji/features/account/data/repositories/account_repository_impl.dart';
import 'package:suikouji/features/account/presentation/providers/account_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    final dao = AccountDao(db);
    final prefs = await SharedPreferences.getInstance();
    final repo = AccountRepositoryImpl(dao, prefs);

    container = ProviderContainer(
      overrides: [accountRepositoryProvider.overrideWith((_) => repo)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('accountListProvider', () {
    test('returns active accounts from seeded data', () async {
      final accounts = await container.read(accountListProvider.future);
      expect(accounts, isNotEmpty);
      expect(accounts.every((a) => !a.isArchived), isTrue);
    });
  });

  group('defaultAccountProvider', () {
    test('returns the preset 钱包 account', () async {
      final account = await container.read(defaultAccountProvider.future);
      expect(account, isNotNull);
      expect(account!.name, '钱包');
      expect(account.isPreset, isTrue);
    });
  });

  group('multiAccountEnabledProvider', () {
    test('defaults to false', () async {
      final enabled = await container.read(multiAccountEnabledProvider.future);
      expect(enabled, isFalse);
    });

    test('reflects toggled state after repo update', () async {
      final repo = await container.read(accountRepositoryProvider.future);
      await repo.setMultiAccountEnabled(enabled: true);

      // Invalidate to re-read
      container.invalidate(multiAccountEnabledProvider);
      final enabled = await container.read(multiAccountEnabledProvider.future);
      expect(enabled, isTrue);
    });
  });
}
