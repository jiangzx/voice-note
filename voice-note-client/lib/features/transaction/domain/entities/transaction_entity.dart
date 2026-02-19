/// Transaction type enumeration.
enum TransactionType {
  expense,
  income,
  transfer;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere((e) => e.name == value);
  }
}

/// Transfer direction for transfer-type transactions.
enum TransferDirection {
  inbound,
  outbound;

  String toStorageString() => this == inbound ? 'in' : 'out';

  static TransferDirection fromString(String value) {
    return value == 'in' ? inbound : outbound;
  }
}

/// Immutable domain entity for Transaction.
class TransactionEntity {
  final String id;
  final TransactionType type;
  final double amount;
  final String currency;
  final DateTime date;
  final String? description;
  final String? categoryId;
  final String accountId;
  final TransferDirection? transferDirection;
  final String? counterparty;
  final String? linkedTransactionId;
  final bool isDraft;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionEntity({
    required this.id,
    required this.type,
    required this.amount,
    this.currency = 'CNY',
    required this.date,
    this.description,
    this.categoryId,
    required this.accountId,
    this.transferDirection,
    this.counterparty,
    this.linkedTransactionId,
    this.isDraft = false,
    required this.createdAt,
    required this.updatedAt,
  });

  TransactionEntity copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? currency,
    DateTime? date,
    String? Function()? description,
    String? Function()? categoryId,
    String? accountId,
    TransferDirection? Function()? transferDirection,
    String? Function()? counterparty,
    String? Function()? linkedTransactionId,
    bool? isDraft,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      description: description != null ? description() : this.description,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      accountId: accountId ?? this.accountId,
      transferDirection: transferDirection != null
          ? transferDirection()
          : this.transferDirection,
      counterparty: counterparty != null ? counterparty() : this.counterparty,
      linkedTransactionId: linkedTransactionId != null
          ? linkedTransactionId()
          : this.linkedTransactionId,
      isDraft: isDraft ?? this.isDraft,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
