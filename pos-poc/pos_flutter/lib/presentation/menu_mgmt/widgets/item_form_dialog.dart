import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/menu_item.dart';
import '../bloc/menu_mgmt_bloc.dart';
import '../bloc/menu_mgmt_event.dart';
import '../bloc/menu_mgmt_state.dart';

class ItemFormDialog extends StatefulWidget {
  final MenuItem? item; // null = create mode
  final String? defaultCategoryId;

  const ItemFormDialog({super.key, this.item, this.defaultCategoryId});

  static Future<void> show(
    BuildContext context, {
    MenuItem? item,
    String? defaultCategoryId,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<MenuMgmtBloc>(),
        child: ItemFormDialog(item: item, defaultCategoryId: defaultCategoryId),
      ),
    );
  }

  @override
  State<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<ItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _orderController;
  late bool _isActive;
  String? _selectedCategoryId;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _descController =
        TextEditingController(text: widget.item?.description ?? '');
    _priceController = TextEditingController(
      text: widget.item != null ? widget.item!.price.toStringAsFixed(0) : '',
    );
    _orderController = TextEditingController(
      text: (widget.item?.displayOrder ?? 0).toString(),
    );
    _isActive = widget.item?.isAvailable ?? true;
    _selectedCategoryId = widget.item?.categoryId ?? widget.defaultCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇分類')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final description = _descController.text.trim().isEmpty
        ? null
        : _descController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final displayOrder = int.tryParse(_orderController.text.trim()) ?? 0;

    if (_isEdit) {
      context.read<MenuMgmtBloc>().add(UpdateItem(
            id: widget.item!.id,
            categoryId: _selectedCategoryId!,
            name: name,
            description: description,
            price: price,
            isActive: _isActive,
            displayOrder: displayOrder,
          ));
    } else {
      context.read<MenuMgmtBloc>().add(CreateItem(
            categoryId: _selectedCategoryId!,
            name: name,
            description: description,
            price: price,
            isActive: _isActive,
            displayOrder: displayOrder,
          ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuMgmtBloc, MenuMgmtState>(
      builder: (context, state) {
        final categories = state.categories;
        return AlertDialog(
          title: Text(
            _isEdit ? '編輯商品' : '新增商品',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420.w,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: '分類 *',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                    ),
                    items: categories
                        .map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v == null ? '請選擇分類' : null,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '商品名稱 *',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '請輸入商品名稱' : null,
                    autofocus: true,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: '售價 *',
                      border: const OutlineInputBorder(),
                      prefixText: '\$ ',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '請輸入售價';
                      final val = double.tryParse(v.trim());
                      if (val == null || val <= 0) return '請輸入有效金額';
                      return null;
                    },
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: '描述（選填）',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _orderController,
                    decoration: InputDecoration(
                      labelText: '排列順序',
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 12.h),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  SizedBox(height: 4.h),
                  SwitchListTile(
                    title: Text('上架販售', style: TextStyle(fontSize: 14.sp)),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('取消',
                  style: TextStyle(
                      fontSize: 14.sp, color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: _submit,
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(
                _isEdit ? '儲存' : '新增',
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
