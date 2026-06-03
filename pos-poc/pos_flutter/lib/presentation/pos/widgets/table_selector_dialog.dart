import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/table.dart';
import '../../tables/bloc/table_bloc.dart';
import '../../tables/bloc/table_event.dart';
import '../../tables/bloc/table_state.dart';

class TableSelectorDialog extends StatelessWidget {
  final TableModel? currentTable;

  const TableSelectorDialog({super.key, this.currentTable});

  static Future<TableModel?> show(BuildContext context,
      {TableModel? currentTable}) {
    return showDialog<TableModel>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<TableBloc>()..add(const LoadTables()),
        child: TableSelectorDialog(currentTable: currentTable),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('選擇桌位',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)),
      contentPadding: EdgeInsets.all(16.w),
      content: SizedBox(
        width: 400.w,
        height: 300.h,
        child: BlocBuilder<TableBloc, TableState>(
          builder: (context, state) {
            if (state.status == TableLoadStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final availableTables =
                state.tables.where((t) => t.status == 'available').toList();

            if (availableTables.isEmpty) {
              return Center(
                child: Text('目前沒有空桌',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14.sp)),
              );
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.0,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
              ),
              itemCount: availableTables.length,
              itemBuilder: (context, index) {
                final table = availableTables[index];
                final isSelected = currentTable?.id == table.id;
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(table),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          table.tableNumber,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${table.capacity}人',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isSelected
                                ? Colors.white70
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(fontSize: 14.sp)),
        ),
      ],
    );
  }
}
