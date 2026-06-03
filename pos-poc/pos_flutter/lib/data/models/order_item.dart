import 'package:equatable/equatable.dart';

class OrderItem extends Equatable {
  final String id;
  final String orderId;
  final String? itemId;
  final String itemName;
  final int quantity;
  final double price;
  final double subtotal;
  final String? notes;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.itemId,
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      itemId: json['item_id'] as String?,
      itemName: json['item_name'] as String,
      quantity: json['quantity'] as int,
      price: ((json['unit_price'] ?? json['price']) as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'item_id': itemId,
      'item_name': itemName,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [
        id,
        orderId,
        itemId,
        itemName,
        quantity,
        price,
        subtotal,
        notes,
      ];
}
