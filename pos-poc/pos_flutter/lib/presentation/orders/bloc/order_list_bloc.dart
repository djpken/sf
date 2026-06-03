import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/order_repository.dart';
import 'order_list_event.dart';
import 'order_list_state.dart';

class OrderListBloc extends Bloc<OrderListEvent, OrderListState> {
  final OrderRepository _orderRepository;

  OrderListBloc(this._orderRepository) : super(const OrderListState()) {
    on<LoadOrders>(_onLoadOrders);
    on<FilterOrdersByStatus>(_onFilterByStatus);
    on<RefreshOrders>(_onRefreshOrders);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
    on<CancelOrder>(_onCancelOrder);
  }

  Future<void> _onLoadOrders(
      LoadOrders event, Emitter<OrderListState> emit) async {
    emit(state.copyWith(status: OrderListStatus.loading));
    try {
      final orders =
          await _orderRepository.listOrders(status: state.selectedStatus);
      emit(state.copyWith(status: OrderListStatus.loaded, orders: orders));
    } catch (e) {
      emit(state.copyWith(
          status: OrderListStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onFilterByStatus(
      FilterOrdersByStatus event, Emitter<OrderListState> emit) async {
    emit(state.copyWith(
      status: OrderListStatus.loading,
      selectedStatus: event.status,
      clearStatusFilter: event.status == null,
    ));
    try {
      final orders = await _orderRepository.listOrders(status: event.status);
      emit(state.copyWith(status: OrderListStatus.loaded, orders: orders));
    } catch (e) {
      emit(state.copyWith(
          status: OrderListStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onRefreshOrders(
      RefreshOrders event, Emitter<OrderListState> emit) async {
    try {
      final orders =
          await _orderRepository.listOrders(status: state.selectedStatus);
      emit(state.copyWith(status: OrderListStatus.loaded, orders: orders));
    } catch (e) {
      emit(state.copyWith(
          status: OrderListStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateOrderStatus(
      UpdateOrderStatus event, Emitter<OrderListState> emit) async {
    try {
      await _orderRepository.updateStatus(event.orderId, event.status);
      add(const RefreshOrders());
    } catch (e) {
      emit(state.copyWith(
          status: OrderListStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onCancelOrder(
      CancelOrder event, Emitter<OrderListState> emit) async {
    try {
      await _orderRepository.cancelOrder(event.orderId);
      add(const RefreshOrders());
    } catch (e) {
      emit(state.copyWith(
          status: OrderListStatus.error, errorMessage: e.toString()));
    }
  }
}
