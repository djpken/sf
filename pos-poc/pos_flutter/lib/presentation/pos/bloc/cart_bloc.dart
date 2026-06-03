import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/local_db/offline_order_queue.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final OrderRepository _orderRepository;
  final ConnectivityService? _connectivity;
  final OfflineOrderQueue? _offlineQueue;

  CartBloc(
    this._orderRepository, {
    ConnectivityService? connectivity,
    OfflineOrderQueue? offlineQueue,
  })  : _connectivity = connectivity,
        _offlineQueue = offlineQueue,
        super(const CartState()) {
    on<AddItemToCart>(_onAddItem);
    on<RemoveItemFromCart>(_onRemoveItem);
    on<UpdateCartItemQuantity>(_onUpdateQuantity);
    on<ClearCart>(_onClearCart);
    on<SetOrderType>(_onSetOrderType);
    on<SelectTable>(_onSelectTable);
    on<SubmitOrder>(_onSubmitOrder);
    on<CompleteCheckout>(_onCompleteCheckout);
  }

  void _onAddItem(AddItemToCart event, Emitter<CartState> emit) {
    final existingIndex = state.items.indexWhere(
      (item) => item.menuItem.id == event.menuItem.id,
    );

    final updatedItems = List<CartItem>.from(state.items);
    if (existingIndex >= 0) {
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + 1,
      );
    } else {
      updatedItems.add(CartItem(
        menuItem: event.menuItem,
        quantity: 1,
        notes: event.notes,
      ));
    }
    emit(state.copyWith(items: updatedItems));
  }

  void _onRemoveItem(RemoveItemFromCart event, Emitter<CartState> emit) {
    final updatedItems = state.items
        .where((item) => item.menuItem.id != event.menuItemId)
        .toList();
    emit(state.copyWith(items: updatedItems));
  }

  void _onUpdateQuantity(
      UpdateCartItemQuantity event, Emitter<CartState> emit) {
    final updatedItems = List<CartItem>.from(state.items);
    final index = updatedItems.indexWhere(
      (item) => item.menuItem.id == event.menuItemId,
    );
    if (index >= 0) {
      if (event.quantity <= 0) {
        updatedItems.removeAt(index);
      } else {
        updatedItems[index] =
            updatedItems[index].copyWith(quantity: event.quantity);
      }
    }
    emit(state.copyWith(items: updatedItems));
  }

  void _onClearCart(ClearCart event, Emitter<CartState> emit) {
    emit(const CartState());
  }

  void _onSetOrderType(SetOrderType event, Emitter<CartState> emit) {
    emit(state.copyWith(
        orderType: event.orderType, clearTable: event.orderType != 'dine_in'));
  }

  void _onSelectTable(SelectTable event, Emitter<CartState> emit) {
    emit(state.copyWith(selectedTable: event.table));
  }

  Future<void> _onSubmitOrder(
      SubmitOrder event, Emitter<CartState> emit) async {
    if (state.items.isEmpty) return;

    emit(state.copyWith(status: CartStatus.submitting));

    final orderItems = state.items
        .map((item) => {
              'item_id': item.menuItem.id,
              'quantity': item.quantity,
              if (item.notes != null && item.notes!.isNotEmpty)
                'notes': item.notes,
            })
        .toList();

    // Offline path: queue locally and let SyncService upload later
    if (_offlineQueue != null &&
        _connectivity != null &&
        !_connectivity!.isOnline) {
      try {
        final localId = await _offlineQueue!.enqueue(
          orderType: state.orderType,
          tableId: state.selectedTable?.id,
          items: orderItems,
        );
        emit(state.copyWith(
            status: CartStatus.submitted,
            submittedOrderId: 'offline:$localId'));
      } catch (e) {
        emit(state.copyWith(
            status: CartStatus.error, errorMessage: e.toString()));
      }
      return;
    }

    try {
      final order = await _orderRepository.createOrder(
        orderType: state.orderType,
        tableId: state.selectedTable?.id,
        items: orderItems,
      );
      emit(state.copyWith(
          status: CartStatus.submitted, submittedOrderId: order.id));
    } catch (e) {
      emit(
          state.copyWith(status: CartStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onCompleteCheckout(
      CompleteCheckout event, Emitter<CartState> emit) async {
    if (state.items.isEmpty) return;

    emit(state.copyWith(status: CartStatus.submitting));
    try {
      final orderItems = state.items
          .map((item) => {
                'item_id': item.menuItem.id,
                'quantity': item.quantity,
                if (item.notes != null && item.notes!.isNotEmpty)
                  'notes': item.notes,
              })
          .toList();

      final order = await _orderRepository.createOrder(
        orderType: state.orderType,
        tableId: state.selectedTable?.id,
        items: orderItems,
      );

      await _orderRepository.addPayment(
        order.id,
        method: event.paymentMethod,
        amount: event.amount,
        referenceNumber: event.referenceNumber,
      );

      await _orderRepository.updateStatus(order.id, 'completed');

      emit(const CartState(status: CartStatus.submitted));
    } catch (e) {
      emit(
          state.copyWith(status: CartStatus.error, errorMessage: e.toString()));
    }
  }
}
