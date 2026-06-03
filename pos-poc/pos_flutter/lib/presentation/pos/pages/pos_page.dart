import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/cart_event.dart';
import '../bloc/cart_state.dart';
import '../bloc/menu_bloc.dart';
import '../bloc/menu_event.dart';
import '../bloc/menu_state.dart';
import '../widgets/cart_panel.dart';
import '../widgets/menu_category_tabs.dart';
import '../widgets/menu_grid.dart';
import '../widgets/order_type_selector.dart';
import '../widgets/table_selector_dialog.dart';

class POSPage extends StatefulWidget {
  const POSPage({super.key});

  @override
  State<POSPage> createState() => _POSPageState();
}

class _POSPageState extends State<POSPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<MenuBloc>().add(const LoadMenu());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildTopBar(),
                _buildOperationalStrip(),
                BlocBuilder<MenuBloc, MenuState>(
                  builder: (context, menuState) {
                    return MenuCategoryTabs(
                      categories: menuState.categories,
                      selectedCategoryId: menuState.selectedCategoryId,
                      onCategorySelected: (id) {
                        context.read<MenuBloc>().add(SelectCategory(id));
                      },
                    );
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: BlocBuilder<MenuBloc, MenuState>(
                    builder: (context, menuState) {
                      final normalizedQuery = _query.trim().toLowerCase();
                      final items = normalizedQuery.isEmpty
                          ? menuState.items
                          : menuState.items
                              .where((item) =>
                                  item.name
                                      .toLowerCase()
                                      .contains(normalizedQuery) ||
                                  (item.description
                                          ?.toLowerCase()
                                          .contains(normalizedQuery) ??
                                      false))
                              .toList();

                      return MenuGrid(
                        items: items,
                        isLoading: menuState.status == MenuStatus.loading &&
                            menuState.items.isEmpty,
                        onItemTap: (item) {
                          context.read<CartBloc>().add(AddItemToCart(item));
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          SizedBox(
            width: 320.w.clamp(300.0, 380.0),
            child: const CartPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
      color: Colors.white,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Front Counter',
                  style: TextStyle(
                      fontSize: 12.sp, color: AppColors.textSecondary)),
              Text('POS 點餐工作台',
                  style:
                      TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(width: 20.w),
          BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              return OrderTypeSelector(
                selectedType: cartState.orderType,
                onTypeChanged: (type) {
                  context.read<CartBloc>().add(SetOrderType(type));
                },
              );
            },
          ),
          SizedBox(width: 16.w),
          BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              if (cartState.orderType != 'dine_in')
                return const SizedBox.shrink();
              return GestureDetector(
                onTap: () async {
                  final table = await TableSelectorDialog.show(
                    context,
                    currentTable: cartState.selectedTable,
                  );
                  if (table != null && context.mounted) {
                    context.read<CartBloc>().add(SelectTable(table));
                  }
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: cartState.selectedTable != null
                        ? AppColors.primary.withAlpha(30)
                        : AppColors.surface,
                    border: Border.all(
                      color: cartState.selectedTable != null
                          ? AppColors.primary
                          : Colors.grey.shade400,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_restaurant,
                        size: 16.sp,
                        color: cartState.selectedTable != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        cartState.selectedTable != null
                            ? l10n.tableNumber(
                                cartState.selectedTable!.tableNumber)
                            : l10n.selectTable,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: cartState.selectedTable != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: cartState.selectedTable != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          SizedBox(
            width: 280.w.clamp(220.0, 340.0),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: '搜尋商品或描述',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalStrip() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _MetricPill(
              icon: Icons.wifi,
              label: '線上同步',
              value: 'Live',
              color: AppColors.success),
          SizedBox(width: 10.w),
          _MetricPill(
              icon: Icons.receipt_long,
              label: '待處理',
              value: '4',
              color: AppColors.warning),
          SizedBox(width: 10.w),
          _MetricPill(
              icon: Icons.table_restaurant,
              label: '佔用桌',
              value: '3',
              color: AppColors.info),
          const Spacer(),
          Text(
            'Demo Mode 可離線展示',
            style: TextStyle(
                color: Colors.white.withAlpha(210),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.white.withAlpha(36)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 6.w),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withAlpha(210), fontSize: 12.sp)),
          SizedBox(width: 6.w),
          Text(value,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
