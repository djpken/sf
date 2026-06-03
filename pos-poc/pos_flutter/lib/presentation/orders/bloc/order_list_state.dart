import 'package:equatable/equatable.dart';
import '../../../data/models/order.dart';

enum OrderListStatus { initial, loading, loaded, error }

class OrderListState extends Equatable {
  final OrderListStatus status;
  final List<Order> orders;
  final String? selectedStatus;
  final String? errorMessage;

  const OrderListState({
    this.status = OrderListStatus.initial,
    this.orders = const [],
    this.selectedStatus,
    this.errorMessage,
  });

  OrderListState copyWith({
    OrderListStatus? status,
    List<Order>? orders,
    String? selectedStatus,
    bool clearStatusFilter = false,
    String? errorMessage,
  }) {
    return OrderListState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      selectedStatus:
          clearStatusFilter ? null : (selectedStatus ?? this.selectedStatus),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, orders, selectedStatus, errorMessage];
}
