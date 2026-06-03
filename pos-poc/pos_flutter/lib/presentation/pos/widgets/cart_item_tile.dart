import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/cart_state.dart';

class CartItemTile extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.cartItem,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: Row(
        children: [
          // Name + notes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.menuItem.name,
                  style:
                      TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cartItem.notes != null && cartItem.notes!.isNotEmpty)
                  Text(
                    cartItem.notes!,
                    style: TextStyle(
                        fontSize: 11.sp, color: AppColors.textSecondary),
                  ),
                Text(
                  'NT\$ ${cartItem.subtotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Quantity controls
          Row(
            children: [
              _ControlBtn(icon: Icons.remove, onTap: onDecrement),
              SizedBox(
                width: 28.w,
                child: Text(
                  '${cartItem.quantity}',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
              ),
              _ControlBtn(icon: Icons.add, onTap: onIncrement),
              SizedBox(width: 4.w),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close, size: 16.sp, color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24.w,
        height: 24.w,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(4.r),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 14.sp, color: AppColors.textPrimary),
      ),
    );
  }
}
