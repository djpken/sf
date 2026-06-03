import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/menu_item.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: item.isAvailable,
      label: '${item.name}, NT\$ ${item.price.toStringAsFixed(0)}',
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: const BorderSide(color: AppColors.divider),
        ),
        child: InkWell(
          onTap: item.isAvailable ? onTap : null,
          borderRadius: BorderRadius.circular(8.r),
          child: Opacity(
            opacity: item.isAvailable ? 1.0 : 0.5,
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _placeholder(),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: item.isAvailable
                              ? AppColors.primaryLight
                              : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.isAvailable ? '可售' : '停售',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: item.isAvailable
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Expanded(
                    child: Text(
                      item.description ?? '快速加入購物車',
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'NT\$ ${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child:
                            Icon(Icons.add, color: Colors.white, size: 18.sp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 42.w,
      height: 42.w,
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: item.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.restaurant_menu,
                    size: 22.sp, color: AppColors.secondaryDark),
              ),
            )
          : Icon(Icons.restaurant_menu,
              size: 22.sp, color: AppColors.secondaryDark),
    );
  }
}
