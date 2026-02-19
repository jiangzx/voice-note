import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../../features/account/data/account_dao.dart';
import '../../features/budget/data/budget_dao.dart';
import '../../features/category/data/category_dao.dart';
import '../../features/statistics/data/statistics_dao.dart';
import '../../features/transaction/data/transaction_dao.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
AccountDao accountDao(Ref ref) {
  return AccountDao(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
BudgetDao budgetDao(Ref ref) {
  return ref.watch(appDatabaseProvider).budgetDao;
}

@Riverpod(keepAlive: true)
CategoryDao categoryDao(Ref ref) {
  return CategoryDao(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
StatisticsDao statisticsDao(Ref ref) {
  return ref.watch(appDatabaseProvider).statisticsDao;
}

@Riverpod(keepAlive: true)
TransactionDao transactionDao(Ref ref) {
  return TransactionDao(ref.watch(appDatabaseProvider));
}
