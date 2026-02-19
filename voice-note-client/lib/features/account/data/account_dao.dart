import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<List<Account>> getAll() => select(accounts).get();

  Stream<List<Account>> watchAll() => select(accounts).watch();

  Future<List<Account>> getActive() =>
      (select(accounts)..where((a) => a.isArchived.equals(false))).get();

  Stream<List<Account>> watchActive() =>
      (select(accounts)..where((a) => a.isArchived.equals(false))).watch();

  Future<Account?> getById(String id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<Account?> getDefault() => (select(
    accounts,
  )..where((a) => a.isPreset.equals(true))).getSingleOrNull();

  Future<void> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<bool> updateAccount(AccountsCompanion entry) =>
      update(accounts).replace(entry);

  Future<int> deleteById(String id) =>
      (delete(accounts)..where((a) => a.id.equals(id))).go();

  Future<void> archiveById(String id) =>
      (update(accounts)..where((a) => a.id.equals(id))).write(
        const AccountsCompanion(isArchived: Value(true)),
      );
}
