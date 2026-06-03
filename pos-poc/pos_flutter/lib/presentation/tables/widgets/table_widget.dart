import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/table.dart';

class TableWidget extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;

  const TableWidget({super.key, required this.table, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final info = _statusInfo(table.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: info.bgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: info.borderColor, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_restaurant, size: 32.sp, color: info.iconColor),
            SizedBox(height: 6.h),
            Text(
              table.tableNumber,
              style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: info.textColor),
            ),
            SizedBox(height: 2.h),
            Text(
              '${table.capacity} 人',
              style: TextStyle(
                  fontSize: 11.sp, color: info.textColor.withAlpha(180)),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: info.badgeColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                info.label,
                style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({
    String label,
    Color bgColor,
    Color borderColor,
    Color iconColor,
    Color textColor,
    Color badgeColor
  }) _statusInfo(String status) {
    switch (status) {
      case 'available':
        return (
          label: '空桌',
          bgColor: Colors.green.shade50,
          borderColor: Colors.green.shade300,
          iconColor: Colors.green.shade600,
          textColor: Colors.green.shade800,
          badgeColor: Colors.green.shade500,
        );
      case 'occupied':
        return (
          label: '使用中',
          bgColor: Colors.orange.shade50,
          borderColor: Colors.orange.shade300,
          iconColor: Colors.orange.shade600,
          textColor: Colors.orange.shade800,
          badgeColor: Colors.orange.shade500,
        );
      case 'reserved':
        return (
          label: '已預約',
          bgColor: Colors.blue.shade50,
          borderColor: Colors.blue.shade300,
          iconColor: Colors.blue.shade600,
          textColor: Colors.blue.shade800,
          badgeColor: Colors.blue.shade500,
        );
      default:
        return (
          label: status,
          bgColor: AppColors.surface,
          borderColor: Colors.grey.shade300,
          iconColor: AppColors.textSecondary,
          textColor: AppColors.textSecondary,
          badgeColor: Colors.grey,
        );
    }
  }
}
