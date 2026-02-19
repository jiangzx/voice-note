// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'statistics_dao.dart';

// ignore_for_file: type=lint
mixin _$StatisticsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  StatisticsDaoManager get managers => StatisticsDaoManager(this);
}

class StatisticsDaoManager {
  final _$StatisticsDaoMixin _db;
  StatisticsDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
}
