import 'package:equatable/equatable.dart';

class Payment extends Equatable {
  final String id;
  final String orderId;
  final String method;
  final double amount;
  final String? referenceNumber;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.amount,
    this.referenceNumber,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      method: json['method'] as String,
      amount: (json['amount'] as num).toDouble(),
      referenceNumber: json['reference_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'method': method,
      'amount': amount,
      'reference_number': referenceNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        orderId,
        method,
        amount,
        referenceNumber,
        createdAt,
      ];
}
