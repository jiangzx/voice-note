/// Immutable domain entity for Account.
class AccountEntity {
  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final bool isPreset;
  final int sortOrder;
  final double initialBalance;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AccountEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isPreset,
    required this.sortOrder,
    required this.initialBalance,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  AccountEntity copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    String? color,
    bool? isPreset,
    int? sortOrder,
    double? initialBalance,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccountEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isPreset: isPreset ?? this.isPreset,
      sortOrder: sortOrder ?? this.sortOrder,
      initialBalance: initialBalance ?? this.initialBalance,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
