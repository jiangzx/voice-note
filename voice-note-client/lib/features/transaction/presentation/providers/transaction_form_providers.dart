import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/database_provider.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

part 'transaction_form_providers.g.dart';

@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) {
  final txDao = ref.watch(transactionDaoProvider);
  final accountDao = ref.watch(accountDaoProvider);
  return TransactionRepositoryImpl(txDao, accountDao);
}

/// Form state for creating / editing a transaction.
class TransactionFormState {
  final TransactionType selectedType;
  final double amount;
  final String? categoryId;
  final DateTime date;
  final String? description;
  final String? accountId;
  final TransferDirection? transferDirection;
  final String? counterparty;

  const TransactionFormState({
    this.selectedType = TransactionType.expense,
    this.amount = 0,
    this.categoryId,
    required this.date,
    this.description,
    this.accountId,
    this.transferDirection,
    this.counterparty,
  });

  TransactionFormState copyWith({
    TransactionType? selectedType,
    double? amount,
    String? Function()? categoryId,
    DateTime? date,
    String? Function()? description,
    String? Function()? accountId,
    TransferDirection? Function()? transferDirection,
    String? Function()? counterparty,
  }) {
    return TransactionFormState(
      selectedType: selectedType ?? this.selectedType,
      amount: amount ?? this.amount,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      date: date ?? this.date,
      description: description != null ? description() : this.description,
      accountId: accountId != null ? accountId() : this.accountId,
      transferDirection: transferDirection != null
          ? transferDirection()
          : this.transferDirection,
      counterparty: counterparty != null ? counterparty() : this.counterparty,
    );
  }
}

@riverpod
class TransactionForm extends _$TransactionForm {
  @override
  TransactionFormState build() => TransactionFormState(date: DateTime.now());

  void setType(TransactionType type) {
    state = state.copyWith(selectedType: type);
  }

  void setAmount(double amount) {
    state = state.copyWith(amount: amount);
  }

  void setCategoryId(String? id) {
    state = state.copyWith(categoryId: () => id);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setDescription(String? desc) {
    state = state.copyWith(description: () => desc);
  }

  void setAccountId(String? id) {
    state = state.copyWith(accountId: () => id);
  }

  void setTransferDirection(TransferDirection? dir) {
    state = state.copyWith(transferDirection: () => dir);
  }

  void setCounterparty(String? value) {
    state = state.copyWith(counterparty: () => value);
  }

  void reset() {
    state = TransactionFormState(date: DateTime.now());
  }

  /// Load an existing entity into the form for editing.
  void loadFromEntity(TransactionEntity entity) {
    state = TransactionFormState(
      selectedType: entity.type,
      amount: entity.amount,
      categoryId: entity.categoryId,
      date: entity.date,
      description: entity.description,
      accountId: entity.accountId,
      transferDirection: entity.transferDirection,
      counterparty: entity.counterparty,
    );
  }
}
