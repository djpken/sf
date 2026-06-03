import 'package:equatable/equatable.dart';

class TableModel extends Equatable {
  final String id;
  final String storeId;
  final String tableNumber;
  final int capacity;
  final String? area;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TableModel({
    required this.id,
    required this.storeId,
    required this.tableNumber,
    required this.capacity,
    this.area,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      tableNumber:
          (json['name'] as String?) ?? (json['table_number'] as String?) ?? '',
      capacity: json['capacity'] as int,
      area: json['area'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'table_number': tableNumber,
      'capacity': capacity,
      'area': area,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        tableNumber,
        capacity,
        area,
        status,
        createdAt,
        updatedAt,
      ];
}
