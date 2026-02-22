import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions, Categories, Accounts])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<List<Transaction>> getAll() =>
      (select(transactions)..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.date),
          ]))
          .get();

  Stream<List<Transaction>> watchAll() =>
      (select(transactions)..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.date),
          ]))
          .watch();

  Future<Transaction?> getById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<bool> updateTransaction(TransactionsCompanion entry) =>
      update(transactions).replace(entry);

  Future<int> deleteById(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// Delete multiple transactions by IDs.
  Future<int> deleteByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(transactions)..where((t) => t.id.isIn(ids))).go();
  }

  /// Clear linked_transaction_id on the partner record when deleting one side.
  Future<void> unlinkPartner(String transactionId) =>
      (update(transactions)
            ..where((t) => t.linkedTransactionId.equals(transactionId)))
          .write(const TransactionsCompanion(linkedTransactionId: Value(null)));

  /// Clear linked_transaction_id on partner records when deleting multiple transactions.
  Future<void> unlinkPartners(List<String> transactionIds) {
    if (transactionIds.isEmpty) return Future.value();
    return (update(transactions)
          ..where((t) => t.linkedTransactionId.isIn(transactionIds)))
        .write(const TransactionsCompanion(linkedTransactionId: Value(null)));
  }

  /// Get filtered transactions with optional criteria.
  Future<List<Transaction>> getFiltered({
    DateTime? dateFrom,
    DateTime? dateTo,
    List<String>? categoryIds,
    String? accountId,
    double? minAmount,
    double? maxAmount,
    String? keyword,
    String? type,
    int? limit,
    int? offset,
  }) {
    final query = select(transactions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.date),
      ]);

    query.where((t) {
      Expression<bool> expr = const Constant(true);
      if (dateFrom != null) {
        expr = expr & t.date.isBiggerOrEqualValue(dateFrom);
      }
      if (dateTo != null) {
        expr = expr & t.date.isSmallerOrEqualValue(dateTo);
      }
      if (categoryIds != null && categoryIds.isNotEmpty) {
        expr = expr & t.categoryId.isIn(categoryIds);
      }
      if (accountId != null) {
        expr = expr & t.accountId.equals(accountId);
      }
      if (minAmount != null) {
        expr = expr & t.amount.isBiggerOrEqualValue(minAmount);
      }
      if (maxAmount != null) {
        expr = expr & t.amount.isSmallerOrEqualValue(maxAmount);
      }
      if (keyword != null && keyword.isNotEmpty) {
        expr = expr & t.description.like('%$keyword%');
      }
      if (type != null) {
        expr = expr & t.type.equals(type);
      }
      return expr;
    });

    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Get income/expense summary for a date range. Includes transfer: in=income, out=expense.
  Future<({double totalIncome, double totalExpense})> getSummary({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final sumCol = transactions.amount.sum();
    final baseFilter = transactions.date.isBiggerOrEqualValue(dateFrom) &
        transactions.date.isSmallerOrEqualValue(dateTo) &
        transactions.isDraft.equals(false);
    final incomeFilter = baseFilter &
        (transactions.type.equals('income') |
            (transactions.type.equals('transfer') &
                transactions.transferDirection.equals('in')));
    final expenseFilter = baseFilter &
        (transactions.type.equals('expense') |
            (transactions.type.equals('transfer') &
                transactions.transferDirection.equals('out')));

    final incomeQuery = selectOnly(transactions)
      ..addColumns([sumCol])
      ..where(incomeFilter);
    final expenseQuery = selectOnly(transactions)
      ..addColumns([sumCol])
      ..where(expenseFilter);
    final incomeRow = await incomeQuery.getSingle();
    final expenseRow = await expenseQuery.getSingle();
    return (
      totalIncome: incomeRow.read(sumCol) ?? 0.0,
      totalExpense: expenseRow.read(sumCol) ?? 0.0,
    );
  }

  /// Get recent N transactions (newest by creation first, so just-recorded items appear at top).
  Future<List<Transaction>> getRecent(int limit) =>
      (select(transactions)
            ..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.date),
            ])
            ..limit(limit))
          .get();

  /// Get a page of recent transactions (createdAt desc, then date desc).
  Future<List<Transaction>> getRecentPage(int limit, int offset) =>
      (select(transactions)
            ..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.date),
            ])
            ..limit(limit, offset: offset))
          .get();

  /// Get recently used category IDs (distinct, up to [limit]).
  Future<List<String>> getRecentCategoryIds(int limit) async {
    final query = selectOnly(transactions, distinct: true)
      ..addColumns([transactions.categoryId])
      ..where(transactions.categoryId.isNotNull())
      ..orderBy([OrderingTerm.desc(transactions.createdAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows
        .map((r) => r.read(transactions.categoryId))
        .whereType<String>()
        .toList();
  }
}
