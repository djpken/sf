import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/menu_category.dart';

class MenuCategoryTabs extends StatelessWidget {
  final List<MenuCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  const MenuCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.h,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == selectedCategoryId;
          return GestureDetector(
            onTap: () => onCategorySelected(category.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14.sp,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
