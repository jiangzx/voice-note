import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../domain/draft_batch.dart';
import '../../domain/parse_result.dart';

/// Persists a single [ParseResult] and returns the created entity.
typedef PersistTransaction = Future<TransactionEntity> Function(
  ParseResult result,
);

/// Persists multiple [ParseResult]s atomically and returns created entities.
typedef PersistBatch = Future<List<TransactionEntity>> Function(
  List<ParseResult> results,
);

/// Encapsulates transaction save-and-track logic during a voice session.
///
/// Responsibilities:
/// - Persist [ParseResult]s (single or batch) via injected callbacks
/// - Track saved amounts for session summary
/// - Invalidate stale queries after each save
/// - Trigger budget checks for expense items
class TransactionSaveHelper {
  final PersistTransaction _persist;
  final PersistBatch? _persistBatch;
  final void Function() _invalidateQueries;
  final void Function(TransactionEntity entity) _checkBudget;

  final List<SavedTransaction> _transactions = [];

  TransactionSaveHelper({
    required PersistTransaction persist,
    PersistBatch? persistBatch,
    required void Function() invalidateQueries,
    required void Function(TransactionEntity) checkBudget,
  })  : _persist = persist,
        _persistBatch = persistBatch,
        _invalidateQueries = invalidateQueries,
        _checkBudget = checkBudget;

  bool get hasTransactions => _transactions.isNotEmpty;
  int get count => _transactions.length;

  double get totalAmount => _transactions
      .where((t) => t.amount != null)
      .fold(0.0, (s, t) => s + t.amount!);

  /// Save one result: persist -> track -> invalidate -> budget check.
  /// Throws on persistence failure (caller decides error UX).
  Future<TransactionEntity> saveOne(ParseResult result) async {
    final entity = await _persist(result);
    _transactions.add(
      SavedTransaction(amount: result.amount, category: result.category),
    );
    _invalidateQueries();
    _checkBudget(entity);
    return entity;
  }

  /// Save confirmed batch items atomically when [PersistBatch] is available,
  /// falling back to sequential saves otherwise.
  Future<BatchSaveResult> saveBatch(List<DraftTransaction> items) async {
    if (items.isEmpty) {
      return const BatchSaveResult(savedCount: 0, errors: []);
    }

    final results = items.map((i) => i.result).toList();

    if (_persistBatch != null) {
      return _atomicBatchSave(results);
    }
    return _sequentialBatchSave(items);
  }

  Future<BatchSaveResult> _atomicBatchSave(List<ParseResult> results) async {
    try {
      final entities = await _persistBatch!(results);
      for (var i = 0; i < results.length; i++) {
        _transactions.add(SavedTransaction(
          amount: results[i].amount,
          category: results[i].category,
        ));
      }
      _invalidateQueries();
      for (final entity in entities) {
        _checkBudget(entity);
      }
      return BatchSaveResult(savedCount: entities.length, errors: const []);
    } catch (e) {
      return BatchSaveResult(savedCount: 0, errors: ['$e']);
    }
  }

  Future<BatchSaveResult> _sequentialBatchSave(
    List<DraftTransaction> items,
  ) async {
    int saved = 0;
    final errors = <String>[];
    for (final item in items) {
      try {
        await saveOne(item.result);
        saved++;
      } catch (e) {
        errors.add('$e');
      }
    }
    return BatchSaveResult(savedCount: saved, errors: errors);
  }

  /// Build session summary text, or null if no transactions.
  String? buildSummaryText() {
    if (_transactions.isEmpty) return null;
    final buf = StringBuffer()..write('本次共记录 $count 笔');
    if (totalAmount > 0) {
      buf.write('，合计 ¥${totalAmount.toStringAsFixed(2)}');
    }
    return buf.toString();
  }

  void clear() => _transactions.clear();
}

/// Tracks one saved transaction for session-level summary.
class SavedTransaction {
  final double? amount;
  final String? category;

  const SavedTransaction({this.amount, this.category});
}

/// Result of a batch save operation.
class BatchSaveResult {
  final int savedCount;
  final List<String> errors;

  const BatchSaveResult({required this.savedCount, required this.errors});

  bool get hasErrors => errors.isNotEmpty;
  bool get allFailed => savedCount == 0 && errors.isNotEmpty;
}
