import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/menu_item.dart';
import 'menu_item_card.dart';

class MenuGrid extends StatelessWidget {
  final List<MenuItem> items;
  final bool isLoading;
  final ValueChanged<MenuItem> onItemTap;

  const MenuGrid({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu,
                size: 48.sp, color: AppColors.textSecondary),
            SizedBox(height: 12.h),
            Text(
              '此分類沒有商品',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 700
                ? 3
                : 2;

        return GridView.builder(
          padding: EdgeInsets.all(16.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.08,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return MenuItemCard(
              item: item,
              onTap: () => onItemTap(item),
            );
          },
        );
      },
    );
  }
}
