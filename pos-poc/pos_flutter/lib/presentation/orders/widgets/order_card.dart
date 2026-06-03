import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/order.dart';
import 'order_status_chip.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('#${order.orderNumber}',
                      style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8.w),
                  OrderStatusChip(status: order.status),
                  const Spacer(),
                  Text('NT\$ ${order.total.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  _InfoChip(
                    icon: _orderTypeIcon(order.orderType),
                    label: _orderTypeLabel(l10n, order.orderType),
                  ),
                  if (order.tableName != null) ...[
                    SizedBox(width: 8.w),
                    _InfoChip(
                        icon: Icons.table_restaurant,
                        label: l10n.tableNumber(order.tableName!)),
                  ],
                  SizedBox(width: 8.w),
                  _InfoChip(
                      icon: Icons.receipt_long, label: '${order.items.length}'),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                order.items
                    .map((i) => '${i.itemName} x${i.quantity}')
                    .take(3)
                    .join('、'),
                style:
                    TextStyle(fontSize: 12.sp, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 6.h),
              Text(_formatTime(order.createdAt),
                  style: TextStyle(
                      fontSize: 11.sp, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _orderTypeIcon(String type) {
    switch (type) {
      case 'dine_in':
        return Icons.restaurant;
      case 'takeout':
        return Icons.shopping_bag;
      case 'delivery':
        return Icons.delivery_dining;
      default:
        return Icons.receipt;
    }
  }

  String _orderTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'dine_in':
        return l10n.dineIn;
      case 'takeout':
        return l10n.takeout;
      case 'delivery':
        return l10n.delivery;
      default:
        return type;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(6.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: AppColors.textSecondary),
          SizedBox(width: 4.w),
          Text(label,
              style:
                  TextStyle(fontSize: 11.sp, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
