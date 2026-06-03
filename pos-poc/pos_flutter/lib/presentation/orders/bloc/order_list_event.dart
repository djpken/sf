import 'package:equatable/equatable.dart';

abstract class OrderListEvent extends Equatable {
  const OrderListEvent();

  @override
  List<Object?> get props => [];
}

class LoadOrders extends OrderListEvent {
  const LoadOrders();
}

class FilterOrdersByStatus extends OrderListEvent {
  final String? status;
  const FilterOrdersByStatus(this.status);

  @override
  List<Object?> get props => [status];
}

class RefreshOrders extends OrderListEvent {
  const RefreshOrders();
}

class UpdateOrderStatus extends OrderListEvent {
  final String orderId;
  final String status;

  const UpdateOrderStatus(this.orderId, this.status);

  @override
  List<Object?> get props => [orderId, status];
}

class CancelOrder extends OrderListEvent {
  final String orderId;
  const CancelOrder(this.orderId);

  @override
  List<Object?> get props => [orderId];
}
