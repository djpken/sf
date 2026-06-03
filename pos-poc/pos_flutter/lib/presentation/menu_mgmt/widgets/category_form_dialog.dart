import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/menu_category.dart';
import '../bloc/menu_mgmt_bloc.dart';
import '../bloc/menu_mgmt_event.dart';

class CategoryFormDialog extends StatefulWidget {
  final MenuCategory? category; // null = create mode

  const CategoryFormDialog({super.key, this.category});

  static Future<void> show(BuildContext context, {MenuCategory? category}) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<MenuMgmtBloc>(),
        child: CategoryFormDialog(category: category),
      ),
    );
  }

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _orderController;
  late bool _isActive;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController =
        TextEditingController(text: widget.category?.description ?? '');
    _orderController = TextEditingController(
      text: (widget.category?.displayOrder ?? 0).toString(),
    );
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final description = _descController.text.trim().isEmpty
        ? null
        : _descController.text.trim();
    final displayOrder = int.tryParse(_orderController.text.trim()) ?? 0;

    if (_isEdit) {
      context.read<MenuMgmtBloc>().add(UpdateCategory(
            id: widget.category!.id,
            name: name,
            description: description,
            displayOrder: displayOrder,
            isActive: _isActive,
          ));
    } else {
      context.read<MenuMgmtBloc>().add(CreateCategory(
            name: name,
            description: description,
            displayOrder: displayOrder,
          ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? '編輯分類' : '新增分類',
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400.w,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '分類名稱 *',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '請輸入分類名稱' : null,
                autofocus: true,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: '描述（選填）',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _orderController,
                decoration: InputDecoration(
                  labelText: '排列順序',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (_isEdit) ...[
                SizedBox(height: 12.h),
                SwitchListTile(
                  title: Text('啟用', style: TextStyle(fontSize: 14.sp)),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消',
              style:
                  TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(
            _isEdit ? '儲存' : '新增',
            style: TextStyle(fontSize: 14.sp, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
