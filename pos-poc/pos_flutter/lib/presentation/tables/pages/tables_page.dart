import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/table_repository.dart';
import '../../../core/di/injection.dart';
import '../bloc/table_bloc.dart';
import '../bloc/table_event.dart';
import '../bloc/table_state.dart';
import '../widgets/table_widget.dart';

class TablesPage extends StatefulWidget {
  const TablesPage({super.key});

  @override
  State<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends State<TablesPage> {
  @override
  void initState() {
    super.initState();
    context.read<TableBloc>().add(const LoadTables());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          color: Colors.white,
          child: Row(
            children: [
              Text(l10n.tablesTitle,
                  style:
                      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
              const Spacer(),
              _LegendItem(
                  color: Colors.green.shade500, label: l10n.tableAvailable),
              SizedBox(width: 12.w),
              _LegendItem(
                  color: Colors.orange.shade500, label: l10n.tableOccupied),
              SizedBox(width: 12.w),
              _LegendItem(
                  color: Colors.blue.shade500, label: l10n.tableReserved),
              SizedBox(width: 12.w),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () =>
                    context.read<TableBloc>().add(const RefreshTables()),
                tooltip: l10n.refresh,
              ),
            ],
          ),
        ),

        // Area filter
        BlocBuilder<TableBloc, TableState>(
          builder: (context, state) {
            if (state.availableAreas.isEmpty) return const SizedBox.shrink();
            return Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(l10n.filterAll,
                          style: TextStyle(fontSize: 13.sp)),
                      selected: state.selectedArea == null,
                      onSelected: (_) => context
                          .read<TableBloc>()
                          .add(const FilterTablesByArea(null)),
                      selectedColor: AppColors.primary.withAlpha(40),
                      checkmarkColor: AppColors.primary,
                    ),
                    ...state.availableAreas.map((area) => Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: FilterChip(
                            label:
                                Text(area, style: TextStyle(fontSize: 13.sp)),
                            selected: state.selectedArea == area,
                            onSelected: (_) => context
                                .read<TableBloc>()
                                .add(FilterTablesByArea(area)),
                            selectedColor: AppColors.primary.withAlpha(40),
                            checkmarkColor: AppColors.primary,
                          ),
                        )),
                  ],
                ),
              ),
            );
          },
        ),

        const Divider(height: 1),

        // Tables grid
        Expanded(
          child: BlocBuilder<TableBloc, TableState>(
            builder: (context, state) {
              if (state.status == TableLoadStatus.loading &&
                  state.tables.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.status == TableLoadStatus.error) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48.sp, color: AppColors.error),
                      SizedBox(height: 12.h),
                      Text(state.errorMessage ?? l10n.loadFailed,
                          style: TextStyle(
                              color: AppColors.error, fontSize: 14.sp)),
                      SizedBox(height: 12.h),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<TableBloc>().add(const LoadTables()),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                );
              }

              final displayTables = state.filteredTables;

              if (displayTables.isEmpty) {
                return Center(
                  child: Text(l10n.noTables,
                      style: TextStyle(
                          fontSize: 16.sp, color: AppColors.textSecondary)),
                );
              }

              return GridView.builder(
                padding: EdgeInsets.all(16.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                ),
                itemCount: displayTables.length,
                itemBuilder: (context, index) {
                  final table = displayTables[index];
                  return TableWidget(
                    table: table,
                    onTap: () => _showTableDetail(context, table, state, l10n),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTableDetail(
      BuildContext context, table, TableState state, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_restaurant,
                    color: AppColors.primary, size: 24.sp),
                SizedBox(width: 8.w),
                Text(
                  l10n.tableNumber(table.tableNumber),
                  style:
                      TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: table.status == 'available'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    _tableStatusLabel(l10n, table.status),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: table.status == 'available'
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(l10n.tableCapacity(table.capacity as int),
                style: TextStyle(fontSize: 14.sp)),
            if (table.area != null)
              Text(l10n.tableArea(table.area),
                  style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 20.h),
            if (table.status == 'occupied')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await getIt<TableRepository>()
                        .updateTableStatus(table.id, 'available');
                    if (context.mounted) {
                      context.read<TableBloc>().add(const RefreshTables());
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l10n.markAsAvailable,
                      style: TextStyle(fontSize: 14.sp)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _tableStatusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'available':
        return l10n.tableAvailable;
      case 'occupied':
        return l10n.tableOccupied;
      case 'reserved':
        return l10n.tableReserved;
      default:
        return status;
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 4.w),
        Text(label,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
      ],
    );
  }
}
