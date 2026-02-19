import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/account_repository.dart';
import '../account_dao.dart';

const _multiAccountKey = 'multi_account_enabled';

class AccountRepositoryImpl implements AccountRepository {
  final AccountDao _dao;
  final SharedPreferences _prefs;

  const AccountRepositoryImpl(this._dao, this._prefs);

  @override
  Future<List<AccountEntity>> getAll() async {
    final rows = await _dao.getAll();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<AccountEntity>> getActive() async {
    final rows = await _dao.getActive();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<AccountEntity?> getById(String id) async {
    final row = await _dao.getById(id);
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<AccountEntity?> getDefault() async {
    final row = await _dao.getDefault();
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<void> create(AccountEntity account) async {
    await _dao.insertAccount(_toCompanion(account));
  }

  @override
  Future<void> update(AccountEntity account) async {
    final updated = account.copyWith(updatedAt: DateTime.now());
    await _dao.updateAccount(_toCompanion(updated));
  }

  @override
  Future<void> archive(String id) async {
    final existing = await _dao.getById(id);
    if (existing != null && existing.isPreset) {
      throw StateError('Cannot archive preset account');
    }
    await _dao.archiveById(id);
  }

  @override
  Future<void> deleteById(String id) async {
    final existing = await _dao.getById(id);
    if (existing != null && existing.isPreset) {
      throw StateError('Cannot delete preset account');
    }
    await _dao.deleteById(id);
  }

  @override
  Future<bool> isMultiAccountEnabled() async {
    return _prefs.getBool(_multiAccountKey) ?? false;
  }

  @override
  Future<void> setMultiAccountEnabled({required bool enabled}) async {
    await _prefs.setBool(_multiAccountKey, enabled);
  }

  // ── Mapping helpers ──

  AccountEntity _toEntity(Account row) {
    return AccountEntity(
      id: row.id,
      name: row.name,
      type: row.type,
      icon: row.icon,
      color: row.color,
      isPreset: row.isPreset,
      sortOrder: row.sortOrder,
      initialBalance: row.initialBalance,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  AccountsCompanion _toCompanion(AccountEntity e) {
    return AccountsCompanion(
      id: Value(e.id),
      name: Value(e.name),
      type: Value(e.type),
      icon: Value(e.icon),
      color: Value(e.color),
      isPreset: Value(e.isPreset),
      sortOrder: Value(e.sortOrder),
      initialBalance: Value(e.initialBalance),
      isArchived: Value(e.isArchived),
      createdAt: Value(e.createdAt),
      updatedAt: Value(e.updatedAt),
    );
  }
}
