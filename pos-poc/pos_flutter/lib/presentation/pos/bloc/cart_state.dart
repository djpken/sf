import 'package:equatable/equatable.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/table.dart';

enum CartStatus { idle, submitting, submitted, error }

class CartItem extends Equatable {
  final MenuItem menuItem;
  final int quantity;
  final String? notes;

  const CartItem({
    required this.menuItem,
    required this.quantity,
    this.notes,
  });

  CartItem copyWith({int? quantity, String? notes}) {
    return CartItem(
      menuItem: menuItem,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  double get subtotal => menuItem.price * quantity;

  @override
  List<Object?> get props => [menuItem, quantity, notes];
}

class CartState extends Equatable {
  final List<CartItem> items;
  final String orderType;
  final TableModel? selectedTable;
  final CartStatus status;
  final String? errorMessage;
  final String? submittedOrderId;

  const CartState({
    this.items = const [],
    this.orderType = 'dine_in',
    this.selectedTable,
    this.status = CartStatus.idle,
    this.errorMessage,
    this.submittedOrderId,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get tax => subtotal * 0.05;
  double get total => subtotal + tax;
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({
    List<CartItem>? items,
    String? orderType,
    TableModel? selectedTable,
    bool clearTable = false,
    CartStatus? status,
    String? errorMessage,
    String? submittedOrderId,
  }) {
    return CartState(
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      selectedTable: clearTable ? null : (selectedTable ?? this.selectedTable),
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      submittedOrderId: submittedOrderId ?? this.submittedOrderId,
    );
  }

  @override
  List<Object?> get props =>
      [items, orderType, selectedTable, status, errorMessage, submittedOrderId];
}
