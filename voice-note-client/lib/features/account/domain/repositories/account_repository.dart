import '../entities/account_entity.dart';

/// Contract for account data access.
abstract class AccountRepository {
  Future<List<AccountEntity>> getAll();
  Future<List<AccountEntity>> getActive();
  Future<AccountEntity?> getById(String id);
  Future<AccountEntity?> getDefault();
  Future<void> create(AccountEntity account);
  Future<void> update(AccountEntity account);
  Future<void> archive(String id);
  Future<void> deleteById(String id);
  Future<bool> isMultiAccountEnabled();
  Future<void> setMultiAccountEnabled({required bool enabled});
}
