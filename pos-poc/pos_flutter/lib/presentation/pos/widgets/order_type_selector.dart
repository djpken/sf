import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';

class OrderTypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onTypeChanged;

  const OrderTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _TypeButton(
            label: l10n.dineIn,
            value: 'dine_in',
            selected: selectedType == 'dine_in',
            onTap: onTypeChanged),
        SizedBox(width: 8.w),
        _TypeButton(
            label: l10n.takeout,
            value: 'takeout',
            selected: selectedType == 'takeout',
            onTap: onTypeChanged),
        SizedBox(width: 8.w),
        _TypeButton(
            label: l10n.delivery,
            value: 'delivery',
            selected: selectedType == 'delivery',
            onTap: onTypeChanged),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  const _TypeButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.textSecondary),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}
