import 'package:equatable/equatable.dart';

class MenuCategory extends Equatable {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MenuCategory({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] as String,
      storeId:
          (json['tenant_id'] as String?) ?? (json['store_id'] as String?) ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      displayOrder:
          (json['sort_order'] as int?) ?? (json['display_order'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'name': name,
      'description': description,
      'display_order': displayOrder,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        name,
        description,
        displayOrder,
        isActive,
        createdAt,
        updatedAt,
      ];
}
