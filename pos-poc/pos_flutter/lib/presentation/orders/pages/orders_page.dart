import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/order_list_bloc.dart';
import '../bloc/order_list_event.dart';
import '../bloc/order_list_state.dart';
import '../widgets/order_card.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  void initState() {
    super.initState();
    context.read<OrderListBloc>().add(const LoadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final statusFilters = [
      (label: l10n.filterAll, value: null),
      (label: l10n.filterPending, value: 'pending'),
      (label: l10n.filterPreparing, value: 'preparing'),
      (label: l10n.filterReady, value: 'ready'),
      (label: l10n.filterCompleted, value: 'completed'),
      (label: l10n.filterCancelled, value: 'cancelled'),
    ];

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          color: Colors.white,
          child: Row(
            children: [
              Text(l10n.ordersTitle,
                  style:
                      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () =>
                    context.read<OrderListBloc>().add(const RefreshOrders()),
                tooltip: l10n.refresh,
              ),
            ],
          ),
        ),

        // Status filter tabs
        Container(
          color: Colors.white,
          child: BlocBuilder<OrderListBloc, OrderListState>(
            builder: (context, state) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Row(
                  children: statusFilters.map((filter) {
                    final isSelected = state.selectedStatus == filter.value;
                    return Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: FilterChip(
                        label: Text(filter.label,
                            style: TextStyle(fontSize: 13.sp)),
                        selected: isSelected,
                        onSelected: (_) {
                          context
                              .read<OrderListBloc>()
                              .add(FilterOrdersByStatus(filter.value));
                        },
                        selectedColor: AppColors.primary.withAlpha(40),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),

        const Divider(height: 1),

        // Orders list
        Expanded(
          child: BlocBuilder<OrderListBloc, OrderListState>(
            builder: (context, state) {
              if (state.status == OrderListStatus.loading &&
                  state.orders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.status == OrderListStatus.error) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48.sp, color: AppColors.error),
                      SizedBox(height: 12.h),
                      Text(state.errorMessage ?? l10n.loadFailed,
                          style: TextStyle(
                              fontSize: 14.sp, color: AppColors.error)),
                      SizedBox(height: 12.h),
                      ElevatedButton(
                        onPressed: () => context
                            .read<OrderListBloc>()
                            .add(const LoadOrders()),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                );
              }

              if (state.orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 48.sp, color: AppColors.textSecondary),
                      SizedBox(height: 12.h),
                      Text(l10n.noOrders,
                          style: TextStyle(
                              fontSize: 16.sp, color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    context.read<OrderListBloc>().add(const RefreshOrders()),
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: state.orders.length,
                  itemBuilder: (context, index) {
                    final order = state.orders[index];
                    return OrderCard(
                      order: order,
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => OrderDetailPage(order: order)),
                        );
                        if (changed == true && context.mounted) {
                          context
                              .read<OrderListBloc>()
                              .add(const RefreshOrders());
                        }
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
