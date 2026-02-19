import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/account/data/account_dao.dart';
import '../../features/budget/data/budget_dao.dart';
import '../../features/category/data/category_dao.dart';
import '../../features/statistics/data/statistics_dao.dart';
import '../../features/transaction/data/transaction_dao.dart';
import 'seed_data.dart';

part 'app_database.g.dart';

// ─── Table definitions ───

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get type =>
      text()(); // cash, bank_card, credit_card, wechat, alipay, custom
  TextColumn get icon =>
      text().withDefault(const Constant('material:account_balance_wallet'))();
  TextColumn get color => text().withDefault(const Constant('FF009688'))();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  RealColumn get initialBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1)();
  TextColumn get type => text()(); // expense, income
  TextColumn get icon =>
      text().withDefault(const Constant('material:category'))();
  TextColumn get color => text().withDefault(const Constant('FF9E9E9E'))();
  BoolColumn get isPreset => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // expense, income, transfer
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get transferDirection => text().nullable()(); // in, out
  TextColumn get counterparty => text().nullable()();
  TextColumn get linkedTransactionId => text().nullable()();
  BoolColumn get isDraft => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncStatus => text().withDefault(const Constant('local'))();
  TextColumn get remoteId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get yearMonth => text()(); // "YYYY-MM" format
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoryId, yearMonth},
      ];
}

// ─── Database ───

@DriftDatabase(
  tables: [Accounts, Categories, Transactions, Budgets],
  daos: [AccountDao, BudgetDao, CategoryDao, StatisticsDao, TransactionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createIndexes();
        await seedDatabase(this);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(budgets);
        }
        if (from < 3) {
          await _createIndexes();
        }
      },
    );
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_date_type ON transactions(date, type)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tx_is_draft ON transactions(is_draft)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'suikouji.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
