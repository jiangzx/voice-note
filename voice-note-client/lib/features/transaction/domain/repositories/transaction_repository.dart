import '../entities/transaction_entity.dart';
import '../entities/transaction_filter.dart';

/// Contract for transaction CRUD and query operations.
abstract class TransactionRepository {
  // ── CRUD ──
  Future<void> create(TransactionEntity transaction);
  Future<void> createBatch(List<TransactionEntity> transactions);
  Future<void> update(TransactionEntity transaction);

  /// Deletes the transaction and clears linked_transaction_id on any partner.
  Future<void> delete(String id);

  /// Deletes multiple transactions and clears linked_transaction_id on any partners.
  Future<void> deleteBatch(List<String> ids);

  Future<TransactionEntity?> getById(String id);

  // ── Query ──
  Future<List<TransactionEntity>> getFiltered(
    TransactionFilter filter, {
    int? offset,
    int? limit,
  });
  Future<TransactionSummary> getSummary(DateTime dateFrom, DateTime dateTo);
  Future<List<TransactionEntity>> getRecent(int limit);
  Future<List<TransactionEntity>> getRecentPage(int limit, int offset);
  Future<List<DailyTransactionGroup>> getDailyGrouped(
    DateTime dateFrom,
    DateTime dateTo,
  );
}
