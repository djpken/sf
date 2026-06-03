import 'package:equatable/equatable.dart';
import '../../../data/models/menu_item.dart';
import '../../../data/models/table.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class AddItemToCart extends CartEvent {
  final MenuItem menuItem;
  final String? notes;

  const AddItemToCart(this.menuItem, {this.notes});

  @override
  List<Object?> get props => [menuItem, notes];
}

class RemoveItemFromCart extends CartEvent {
  final String menuItemId;

  const RemoveItemFromCart(this.menuItemId);

  @override
  List<Object?> get props => [menuItemId];
}

class UpdateCartItemQuantity extends CartEvent {
  final String menuItemId;
  final int quantity;

  const UpdateCartItemQuantity(this.menuItemId, this.quantity);

  @override
  List<Object?> get props => [menuItemId, quantity];
}

class ClearCart extends CartEvent {
  const ClearCart();
}

class SetOrderType extends CartEvent {
  final String orderType;

  const SetOrderType(this.orderType);

  @override
  List<Object?> get props => [orderType];
}

class SelectTable extends CartEvent {
  final TableModel? table;

  const SelectTable(this.table);

  @override
  List<Object?> get props => [table];
}

class SubmitOrder extends CartEvent {
  const SubmitOrder();
}

class CompleteCheckout extends CartEvent {
  final String paymentMethod;
  final double amount;
  final double? received;
  final String? referenceNumber;

  const CompleteCheckout({
    required this.paymentMethod,
    required this.amount,
    this.received,
    this.referenceNumber,
  });

  @override
  List<Object?> get props => [paymentMethod, amount, received, referenceNumber];
}
