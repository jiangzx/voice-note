import 'package:uuid/uuid.dart';

import '../../category/data/category_dao.dart';
import '../../transaction/domain/entities/transaction_entity.dart';
import '../../transaction/domain/repositories/transaction_repository.dart';
import '../../../core/database/app_database.dart';
import '../../account/data/account_dao.dart';
import '../domain/parse_result.dart';

/// Maps [ParseResult] from voice/NLP to [TransactionEntity] and persists it.
class VoiceTransactionService {
  final TransactionRepository _transactionRepo;
  final CategoryDao _categoryDao;
  final AccountDao _accountDao;
  static const _uuid = Uuid();

  VoiceTransactionService({
    required TransactionRepository transactionRepo,
    required CategoryDao categoryDao,
    required AccountDao accountDao,
  })  : _transactionRepo = transactionRepo,
        _categoryDao = categoryDao,
        _accountDao = accountDao;

  /// Save multiple [ParseResult]s atomically. If any item fails validation
  /// or persistence, the entire batch is rolled back.
  /// Returns the list of saved entities in order.
  Future<List<TransactionEntity>> saveBatch(List<ParseResult> results) async {
    if (results.isEmpty) return [];
    try {
      final entities = <TransactionEntity>[];
      for (final result in results) {
        entities.add(await _buildEntity(result));
      }
      await _transactionRepo.createBatch(entities);
      return entities;
    } on VoiceSaveException {
      rethrow;
    } catch (e) {
      throw VoiceSaveException('批量保存失败：$e');
    }
  }

  /// Convert [result] into a [TransactionEntity] and save to database.
  /// Returns the saved entity, or throws [VoiceSaveException] on failure.
  Future<TransactionEntity> save(ParseResult result) async {
    try {
      final entity = await _buildEntity(result);
      await _transactionRepo.create(entity);
      return entity;
    } on VoiceSaveException {
      rethrow;
    } catch (e) {
      throw VoiceSaveException('保存交易失败：$e');
    }
  }

  Future<TransactionEntity> _buildEntity(ParseResult result) async {
    if (result.amount == null || result.amount! <= 0) {
      throw const VoiceSaveException('金额无效');
    }
    final type = _mapType(result.type);
    final categoryId = await _resolveCategoryId(result.category, type);
    final accountId = await _resolveAccountId(result.account);
    final date = _parseDate(result.date) ?? DateTime.now();
    final now = DateTime.now();
    return TransactionEntity(
      id: _uuid.v4(),
      type: type,
      amount: result.amount!,
      currency: 'CNY',
      date: date,
      description: result.description,
      categoryId: categoryId,
      accountId: accountId,
      createdAt: now,
      updatedAt: now,
    );
  }

  TransactionType _mapType(String typeStr) {
    return switch (typeStr.toUpperCase()) {
      'INCOME' => TransactionType.income,
      'TRANSFER' => TransactionType.transfer,
      _ => TransactionType.expense,
    };
  }

  /// Resolve category name → categoryId by fuzzy matching against DB records.
  /// Falls back to the first available category when no match is found, since
  /// the repository requires a category for non-transfer transactions.
  Future<String?> _resolveCategoryId(
      String? categoryName, TransactionType type) async {
    if (type == TransactionType.transfer) return null;

    final typeStr = type == TransactionType.income ? 'income' : 'expense';
    final categories = await _categoryDao.getByType(typeStr);
    if (categories.isEmpty) return null;

    if (categoryName != null) {
      final exact = categories.cast<Category?>().firstWhere(
            (c) => c!.name == categoryName,
            orElse: () => null,
          );
      if (exact != null) return exact.id;

      final partial = categories.cast<Category?>().firstWhere(
            (c) =>
                c!.name.contains(categoryName) ||
                categoryName.contains(c.name),
            orElse: () => null,
          );
      if (partial != null) return partial.id;
    }

    return categories.first.id;
  }

  /// Resolve account name → accountId, falling back to default account.
  Future<String> _resolveAccountId(String? accountName) async {
    if (accountName != null) {
      final all = await _accountDao.getActive();
      final match = all.cast<Account?>().firstWhere(
            (a) => a!.name == accountName,
            orElse: () => null,
          );
      if (match != null) return match.id;
    }

    // Fall back to default (preset) account
    final defaultAccount = await _accountDao.getDefault();
    if (defaultAccount != null) return defaultAccount.id;

    // Last resort: first active account
    final active = await _accountDao.getActive();
    if (active.isNotEmpty) return active.first.id;

    throw const VoiceSaveException('没有可用的账户');
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }
}

/// Thrown when voice transaction save fails.
class VoiceSaveException implements Exception {
  final String message;
  const VoiceSaveException(this.message);

  @override
  String toString() => 'VoiceSaveException: $message';
}
