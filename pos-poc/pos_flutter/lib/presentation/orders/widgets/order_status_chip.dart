import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';

class OrderStatusChip extends StatelessWidget {
  final String status;

  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final info = _statusInfo(status, l10n);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: info.color.withAlpha(30),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: info.color.withAlpha(100)),
      ),
      child: Text(
        info.label,
        style: TextStyle(
            fontSize: 11.sp, color: info.color, fontWeight: FontWeight.w600),
      ),
    );
  }

  ({String label, Color color}) _statusInfo(
      String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return (label: l10n.statusPending, color: AppColors.warning);
      case 'preparing':
        return (label: l10n.statusPreparing, color: Colors.blue);
      case 'ready':
        return (label: l10n.statusReady, color: AppColors.success);
      case 'completed':
        return (label: l10n.statusCompleted, color: Colors.grey);
      case 'cancelled':
        return (label: l10n.statusCancelled, color: AppColors.error);
      default:
        return (label: status, color: Colors.grey);
    }
  }
}
