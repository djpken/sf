import 'package:equatable/equatable.dart';
import 'order_item.dart';
import 'payment.dart';

class Order extends Equatable {
  final String id;
  final String storeId;
  final String? tableId;
  final String? tableName;
  final String orderNumber;
  final String orderType;
  final String status;
  final int? customerCount;
  final List<OrderItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final List<Payment> payments;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.storeId,
    this.tableId,
    this.tableName,
    required this.orderNumber,
    required this.orderType,
    required this.status,
    this.customerCount,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.payments,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      tableId: json['table_id'] as String?,
      tableName: json['table_name'] as String?,
      orderNumber: json['order_number'] as String,
      orderType: json['order_type'] as String,
      status: json['status'] as String,
      customerCount: json['customer_count'] as int?,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      payments: (json['payments'] as List<dynamic>?)
              ?.map((payment) =>
                  Payment.fromJson(payment as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_id': storeId,
      'table_id': tableId,
      'table_name': tableName,
      'order_number': orderNumber,
      'order_type': orderType,
      'status': status,
      'customer_count': customerCount,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'payments': payments.map((payment) => payment.toJson()).toList(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        storeId,
        tableId,
        tableName,
        orderNumber,
        orderType,
        status,
        customerCount,
        items,
        subtotal,
        tax,
        total,
        payments,
        notes,
        createdAt,
        updatedAt,
      ];
}
