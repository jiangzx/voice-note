/// Immutable domain entity for Category.
class CategoryEntity {
  final String id;
  final String name;
  final String type; // expense | income
  final String icon;
  final String color;
  final bool isPreset;
  final bool isHidden;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isPreset,
    required this.isHidden,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  CategoryEntity copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    String? color,
    bool? isPreset,
    bool? isHidden,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isPreset: isPreset ?? this.isPreset,
      isHidden: isHidden ?? this.isHidden,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
