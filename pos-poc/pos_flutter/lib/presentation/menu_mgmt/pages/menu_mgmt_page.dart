import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../bloc/menu_mgmt_bloc.dart';
import '../bloc/menu_mgmt_event.dart';
import '../bloc/menu_mgmt_state.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/item_form_dialog.dart';

class MenuMgmtPage extends StatefulWidget {
  const MenuMgmtPage({super.key});

  @override
  State<MenuMgmtPage> createState() => _MenuMgmtPageState();
}

class _MenuMgmtPageState extends State<MenuMgmtPage> {
  @override
  void initState() {
    super.initState();
    context.read<MenuMgmtBloc>().add(const LoadMenuMgmt());
  }

  Future<bool> _confirmDelete(BuildContext context, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('確認刪除',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
        content:
            Text('確定要刪除「$label」嗎？此操作無法還原。', style: TextStyle(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消',
                style:
                    TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('刪除',
                style: TextStyle(fontSize: 14.sp, color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuMgmtBloc, MenuMgmtState>(
      builder: (context, state) {
        return Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    '菜單管理',
                    style:
                        TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (state.status == MenuMgmtStatus.saving)
                    Padding(
                      padding: EdgeInsets.only(right: 12.w),
                      child: SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.primary),
                    onPressed: () =>
                        context.read<MenuMgmtBloc>().add(const LoadMenuMgmt()),
                    tooltip: '重新整理',
                  ),
                  ElevatedButton.icon(
                    onPressed: () => CategoryFormDialog.show(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    icon: Icon(Icons.add, size: 18.sp, color: Colors.white),
                    label: Text('新增分類',
                        style: TextStyle(fontSize: 14.sp, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Expanded(
              child: _buildBody(context, state),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, MenuMgmtState state) {
    if (state.status == MenuMgmtStatus.loading && state.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == MenuMgmtStatus.error && state.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: AppColors.error),
            SizedBox(height: 12.h),
            Text(
              state.errorMessage ?? '載入失敗',
              style: TextStyle(fontSize: 14.sp, color: AppColors.error),
            ),
            SizedBox(height: 12.h),
            ElevatedButton(
              onPressed: () =>
                  context.read<MenuMgmtBloc>().add(const LoadMenuMgmt()),
              child: const Text('重試'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Left panel: category list
        SizedBox(
          width: 260.w,
          child: _buildCategoryPanel(context, state),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Right panel: item list
        Expanded(
          child: _buildItemPanel(context, state),
        ),
      ],
    );
  }

  Widget _buildCategoryPanel(BuildContext context, MenuMgmtState state) {
    if (state.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined,
                size: 40.sp, color: AppColors.textSecondary),
            SizedBox(height: 8.h),
            Text('尚無分類',
                style:
                    TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.categories.length,
      itemBuilder: (context, index) {
        final category = state.categories[index];
        final isSelected = state.selectedCategoryId == category.id;

        return InkWell(
          onTap: () {
            context.read<MenuMgmtBloc>().add(SelectMgmtCategory(category.id));
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withAlpha(20) : null,
              border: Border(
                left: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (!category.isActive)
                        Text(
                          '已停用',
                          style: TextStyle(
                              fontSize: 11.sp, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      size: 16.sp, color: AppColors.textSecondary),
                  onPressed: () =>
                      CategoryFormDialog.show(context, category: category),
                  tooltip: '編輯',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.all(4.w),
                ),
                SizedBox(width: 4.w),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 16.sp, color: AppColors.error),
                  onPressed: () async {
                    final confirmed =
                        await _confirmDelete(context, category.name);
                    if (confirmed && context.mounted) {
                      context
                          .read<MenuMgmtBloc>()
                          .add(DeleteCategory(category.id));
                    }
                  },
                  tooltip: '刪除',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.all(4.w),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemPanel(BuildContext context, MenuMgmtState state) {
    final selectedCategory = state.categories
        .where((c) => c.id == state.selectedCategoryId)
        .firstOrNull;

    return Column(
      children: [
        // Item panel header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Text(
                selectedCategory != null
                    ? '${selectedCategory.name}（${state.items.length} 項）'
                    : '請選擇分類',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (selectedCategory != null)
                ElevatedButton.icon(
                  onPressed: () => ItemFormDialog.show(
                    context,
                    defaultCategoryId: state.selectedCategoryId,
                  ),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  icon: Icon(Icons.add, size: 18.sp, color: Colors.white),
                  label: Text('新增商品',
                      style: TextStyle(fontSize: 14.sp, color: Colors.white)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Items list
        Expanded(
          child: _buildItemsList(context, state),
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context, MenuMgmtState state) {
    if (state.selectedCategoryId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_back, size: 32.sp, color: AppColors.textSecondary),
            SizedBox(height: 8.h),
            Text('從左側選擇一個分類',
                style:
                    TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (state.status == MenuMgmtStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fastfood_outlined,
                size: 40.sp, color: AppColors.textSecondary),
            SizedBox(height: 8.h),
            Text('此分類尚無商品',
                style:
                    TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: state.items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          title: Row(
            children: [
              Text(item.name,
                  style:
                      TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500)),
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: item.isAvailable
                      ? Colors.green.withAlpha(30)
                      : Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.isAvailable ? '上架' : '下架',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: item.isAvailable
                        ? Colors.green.shade700
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          subtitle: item.description != null && item.description!.isNotEmpty
              ? Text(
                  item.description!,
                  style: TextStyle(
                      fontSize: 12.sp, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$${item.price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 16.w),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 18.sp, color: AppColors.textSecondary),
                onPressed: () => ItemFormDialog.show(context, item: item),
                tooltip: '編輯',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18.sp, color: AppColors.error),
                onPressed: () async {
                  final confirmed = await _confirmDelete(context, item.name);
                  if (confirmed && context.mounted) {
                    context.read<MenuMgmtBloc>().add(DeleteItem(item.id));
                  }
                },
                tooltip: '刪除',
              ),
            ],
          ),
        );
      },
    );
  }
}
