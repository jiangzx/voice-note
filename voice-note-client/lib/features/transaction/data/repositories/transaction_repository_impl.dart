import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../account/data/account_dao.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../transaction_dao.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionDao _dao;
  final AccountDao _accountDao;

  const TransactionRepositoryImpl(this._dao, this._accountDao);

  @override
  Future<void> create(TransactionEntity tx) async {
    _validate(tx);
    final entity = await _applyDefaults(tx);
    await _dao.insertTransaction(_toCompanion(entity));
  }

  @override
  Future<void> createBatch(List<TransactionEntity> txs) async {
    for (final tx in txs) {
      _validate(tx);
    }
    final entities = await Future.wait(txs.map(_applyDefaults));
    await _dao.attachedDatabase.transaction(() async {
      for (final entity in entities) {
        await _dao.insertTransaction(_toCompanion(entity));
      }
    });
  }

  @override
  Future<void> update(TransactionEntity tx) async {
    _validate(tx);
    final updated = tx.copyWith(updatedAt: DateTime.now());
    await _dao.updateTransaction(_toCompanion(updated));
  }

  @override
  Future<void> delete(String id) async {
    // Clear linked_transaction_id on any partner referencing this record
    await _dao.unlinkPartner(id);
    await _dao.deleteById(id);
  }

  @override
  Future<void> deleteBatch(List<String> ids) async {
    if (ids.isEmpty) return;
    // Clear linked_transaction_id on any partners referencing these records
    await _dao.unlinkPartners(ids);
    // Delete all transactions in a transaction for atomicity
    await _dao.attachedDatabase.transaction(() async {
      await _dao.deleteByIds(ids);
    });
  }

  @override
  Future<TransactionEntity?> getById(String id) async {
    final row = await _dao.getById(id);
    return row != null ? _toEntity(row) : null;
  }

  // ── Query ──

  @override
  Future<List<TransactionEntity>> getFiltered(
    TransactionFilter filter, {
    int? offset,
    int? limit,
  }) async {
    final rows = await _dao.getFiltered(
      dateFrom: filter.dateFrom,
      dateTo: filter.dateTo,
      categoryIds: filter.categoryIds,
      accountId: filter.accountId,
      minAmount: filter.minAmount,
      maxAmount: filter.maxAmount,
      keyword: filter.keyword,
      type: filter.type,
      offset: offset,
      limit: limit,
    );
    return rows.map(_toEntity).toList();
  }

  @override
  Future<TransactionSummary> getSummary(
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final result = await _dao.getSummary(dateFrom: dateFrom, dateTo: dateTo);
    return TransactionSummary(
      totalIncome: result.totalIncome,
      totalExpense: result.totalExpense,
    );
  }

  @override
  Future<List<TransactionEntity>> getRecent(int limit) async {
    final rows = await _dao.getRecent(limit);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<TransactionEntity>> getRecentPage(int limit, int offset) async {
    final rows = await _dao.getRecentPage(limit, offset);
    return rows.map(_toEntity).toList();
  }

  @override
  Future<List<DailyTransactionGroup>> getDailyGrouped(
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final rows = await _dao.getFiltered(dateFrom: dateFrom, dateTo: dateTo);
    final grouped = <DateTime, List<Transaction>>{};
    for (final row in rows) {
      final dayKey = DateTime(row.date.year, row.date.month, row.date.day);
      grouped.putIfAbsent(dayKey, () => []).add(row);
    }

    final result = <DailyTransactionGroup>[];
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final day in sortedKeys) {
      final txs = grouped[day]!;
      var income = 0.0;
      var expense = 0.0;
      for (final tx in txs) {
        if (tx.type == 'income') income += tx.amount;
        if (tx.type == 'expense') expense += tx.amount;
        if (tx.type == 'transfer') {
          if (tx.transferDirection == 'in') income += tx.amount;
          if (tx.transferDirection == 'out') expense += tx.amount;
        }
      }
      result.add(
        DailyTransactionGroup(
          date: day,
          dailyIncome: income,
          dailyExpense: expense,
          transactions: txs.map(_toEntity).toList(),
        ),
      );
    }
    return result;
  }

  // ── Validation ──

  void _validate(TransactionEntity tx) {
    if (tx.amount <= 0) {
      throw ArgumentError('Amount must be positive');
    }
    if (tx.type != TransactionType.transfer && tx.categoryId == null) {
      throw ArgumentError('Non-transfer transactions require a category');
    }
  }

  Future<TransactionEntity> _applyDefaults(TransactionEntity tx) async {
    var result = tx;

    // Default currency to CNY
    if (result.currency.isEmpty) {
      result = result.copyWith(currency: 'CNY');
    }

    // Default account to preset account
    if (result.accountId.isEmpty) {
      final defaultAccount = await _accountDao.getDefault();
      if (defaultAccount != null) {
        result = result.copyWith(accountId: defaultAccount.id);
      }
    }

    return result;
  }

  // ── Mapping helpers ──

  TransactionEntity _toEntity(Transaction row) {
    return TransactionEntity(
      id: row.id,
      type: TransactionType.fromString(row.type),
      amount: row.amount,
      currency: row.currency,
      date: row.date,
      description: row.description,
      categoryId: row.categoryId,
      accountId: row.accountId,
      transferDirection: row.transferDirection != null
          ? TransferDirection.fromString(row.transferDirection!)
          : null,
      counterparty: row.counterparty,
      linkedTransactionId: row.linkedTransactionId,
      isDraft: row.isDraft,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  TransactionsCompanion _toCompanion(TransactionEntity e) {
    return TransactionsCompanion(
      id: Value(e.id),
      type: Value(e.type.name),
      amount: Value(e.amount),
      currency: Value(e.currency),
      date: Value(e.date),
      description: Value(e.description),
      categoryId: Value(e.categoryId),
      accountId: Value(e.accountId),
      transferDirection: Value(e.transferDirection?.toStorageString()),
      counterparty: Value(e.counterparty),
      linkedTransactionId: Value(e.linkedTransactionId),
      isDraft: Value(e.isDraft),
      createdAt: Value(e.createdAt),
      updatedAt: Value(e.updatedAt),
    );
  }
}
