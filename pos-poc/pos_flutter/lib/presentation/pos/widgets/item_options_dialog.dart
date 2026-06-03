import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../data/models/menu_item.dart';

class ItemOptionsDialog extends StatefulWidget {
  final MenuItem item;

  const ItemOptionsDialog({super.key, required this.item});

  static Future<String?> show(BuildContext context, MenuItem item) {
    return showDialog<String>(
      context: context,
      builder: (_) => ItemOptionsDialog(item: item),
    );
  }

  @override
  State<ItemOptionsDialog> createState() => _ItemOptionsDialogState();
}

class _ItemOptionsDialogState extends State<ItemOptionsDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.item.description != null &&
              widget.item.description!.isNotEmpty) ...[
            Text(widget.item.description!,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600)),
            SizedBox(height: 8.h),
          ],
          Text(
            'NT\$ ${widget.item.price.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.blue),
          ),
          SizedBox(height: 16.h),
          Text('備註',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 6.h),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '例如：少糖、去冰、不辣...',
              hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            ),
            style: TextStyle(fontSize: 13.sp),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消', style: TextStyle(fontSize: 14.sp)),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(_notesController.text.trim()),
          child: Text('加入購物車', style: TextStyle(fontSize: 14.sp)),
        ),
      ],
    );
  }
}
