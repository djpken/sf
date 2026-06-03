import 'package:equatable/equatable.dart';

class Employee extends Equatable {
  final String id;
  final String tenantId;
  final String storeId;
  final String name;
  final String email;
  final String role;
  final String? pin;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Employee({
    required this.id,
    required this.tenantId,
    required this.storeId,
    required this.name,
    required this.email,
    required this.role,
    this.pin,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      storeId: json['store_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      pin: json['pin'] as String?,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'store_id': storeId,
      'name': name,
      'email': email,
      'role': role,
      'pin': pin,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        storeId,
        name,
        email,
        role,
        pin,
        isActive,
        createdAt,
        updatedAt,
      ];
}
