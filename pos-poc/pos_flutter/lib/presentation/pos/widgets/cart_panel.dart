import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';
import 'cart_item_tile.dart';
import 'checkout_dialog.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<CartBloc, CartState>(
      listener: (context, state) {
        if (state.status == CartStatus.submitted &&
            state.submittedOrderId != null) {
          CheckoutDialog.show(
            context,
            orderId: state.submittedOrderId!,
            totalAmount: state.total,
          ).then((success) {
            if (success) {
              context.read<CartBloc>().add(const ClearCart());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.checkoutCompleted),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          });
        } else if (state.status == CartStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? l10n.orderError),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                color: AppColors.surface,
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart,
                        size: 20.sp, color: AppColors.primary),
                    SizedBox(width: 8.w),
                    Text(l10n.cart,
                        style: TextStyle(
                            fontSize: 16.sp, fontWeight: FontWeight.bold)),
                    if (state.totalItems > 0) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text('${state.totalItems}',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11.sp)),
                      ),
                    ],
                    const Spacer(),
                    if (state.orderType == 'dine_in' &&
                        state.selectedTable != null)
                      Text(
                        l10n.tableNumber(state.selectedTable!.tableNumber),
                        style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Items list
              Expanded(
                child: state.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_shopping_cart,
                                size: 48.sp, color: AppColors.textSecondary),
                            SizedBox(height: 12.h),
                            Text(
                              l10n.cartEmpty,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, indent: 12.w),
                        itemBuilder: (context, index) {
                          final cartItem = state.items[index];
                          return CartItemTile(
                            cartItem: cartItem,
                            onIncrement: () => context.read<CartBloc>().add(
                                  UpdateCartItemQuantity(cartItem.menuItem.id,
                                      cartItem.quantity + 1),
                                ),
                            onDecrement: () => context.read<CartBloc>().add(
                                  UpdateCartItemQuantity(cartItem.menuItem.id,
                                      cartItem.quantity - 1),
                                ),
                            onRemove: () => context.read<CartBloc>().add(
                                  RemoveItemFromCart(cartItem.menuItem.id),
                                ),
                          );
                        },
                      ),
              ),

              // Summary & actions
              if (state.items.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Column(
                    children: [
                      _SummaryRow(
                          label: l10n.subtotal,
                          value: 'NT\$ ${state.subtotal.toStringAsFixed(0)}'),
                      SizedBox(height: 4.h),
                      _SummaryRow(
                          label: l10n.taxLabel,
                          value: 'NT\$ ${state.tax.toStringAsFixed(0)}'),
                      Divider(height: 12.h),
                      _SummaryRow(
                        label: l10n.total,
                        value: 'NT\$ ${state.total.toStringAsFixed(0)}',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            context.read<CartBloc>().add(const ClearCart()),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: Text(l10n.clearCart,
                            style: TextStyle(fontSize: 13.sp)),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state.status == CartStatus.submitting
                              ? null
                              : () {
                                  if (state.orderType == 'dine_in' &&
                                      state.selectedTable == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.selectTableFirst),
                                        backgroundColor: AppColors.warning,
                                      ),
                                    );
                                    return;
                                  }
                                  context
                                      .read<CartBloc>()
                                      .add(const SubmitOrder());
                                },
                          icon: state.status == CartStatus.submitting
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: const CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(Icons.payment, size: 18.sp),
                          label: Text(l10n.checkout,
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow(
      {required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isBold ? 16.sp : 13.sp,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value,
            style: style.copyWith(color: isBold ? AppColors.primary : null)),
      ],
    );
  }
}
