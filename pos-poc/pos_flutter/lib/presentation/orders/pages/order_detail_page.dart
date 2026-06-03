import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/receipt_printer.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../core/di/injection.dart';
import '../widgets/order_status_chip.dart';

class OrderDetailPage extends StatefulWidget {
  final Order order;

  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Order _order;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final updated =
          await getIt<OrderRepository>().updateStatus(_order.id, newStatus);
      setState(() => _order = updated);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.updateFailed(e.toString())),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  Future<void> _cancelOrder() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.confirmCancelTitle),
        content: Text(l10n.confirmCancelMessage(_order.orderNumber)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.no)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.confirmCancelTitle,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _isUpdating = true);
      try {
        await getIt<OrderRepository>().cancelOrder(_order.id);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.cancelFailed(e.toString())),
                backgroundColor: AppColors.error),
          );
          setState(() => _isUpdating = false);
        }
      }
    }
  }

  Future<void> _printReceipt() async {
    await ReceiptPrinter.printOrder(_order);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.orderDetailTitle(_order.orderNumber),
            style: TextStyle(fontSize: 16.sp)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        actions: [
          // Print button
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _printReceipt,
            tooltip: l10n.printReceipt,
          ),
          if (_order.status != 'completed' && _order.status != 'cancelled')
            TextButton.icon(
              onPressed: _isUpdating ? null : _cancelOrder,
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
              label: Text(l10n.cancelOrder,
                  style: TextStyle(color: AppColors.error, fontSize: 13.sp)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Info
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.orderStatus,
                                style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary)),
                            SizedBox(height: 4.h),
                            OrderStatusChip(status: _order.status),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(l10n.orderType,
                                style: TextStyle(
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary)),
                            SizedBox(height: 4.h),
                            Text(_orderTypeLabel(l10n, _order.orderType),
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    if (_order.tableName != null) ...[
                      Divider(height: 16.h),
                      Row(
                        children: [
                          Icon(Icons.table_restaurant,
                              size: 16.sp, color: AppColors.textSecondary),
                          SizedBox(width: 6.w),
                          Text(l10n.tableLabel(_order.tableName!),
                              style: TextStyle(fontSize: 13.sp)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Status actions
            if (_order.status == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isUpdating ? null : () => _updateStatus('preparing'),
                  icon: const Icon(Icons.kitchen),
                  label: Text(l10n.startPreparing,
                      style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            if (_order.status == 'preparing')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : () => _updateStatus('ready'),
                  icon: const Icon(Icons.check_circle),
                  label:
                      Text(l10n.markReady, style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            SizedBox(height: 12.h),

            // Items
            Text(l10n.orderItems,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 8.h),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _order.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _order.items[index];
                  return ListTile(
                    dense: true,
                    title:
                        Text(item.itemName, style: TextStyle(fontSize: 14.sp)),
                    subtitle: item.notes != null && item.notes!.isNotEmpty
                        ? Text(item.notes!,
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textSecondary))
                        : null,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('x ${item.quantity}',
                            style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.textSecondary)),
                        Text('NT\$ ${item.subtotal.toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 13.sp, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),

            // Totals
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    _TotalRow(
                        label: l10n.subtotal,
                        value: 'NT\$ ${_order.subtotal.toStringAsFixed(0)}'),
                    SizedBox(height: 4.h),
                    _TotalRow(
                        label: l10n.taxLabel,
                        value: 'NT\$ ${_order.tax.toStringAsFixed(0)}'),
                    Divider(height: 12.h),
                    _TotalRow(
                        label: l10n.total,
                        value: 'NT\$ ${_order.total.toStringAsFixed(0)}',
                        isBold: true),
                  ],
                ),
              ),
            ),

            // Payments
            if (_order.payments.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Text(l10n.paymentsLabel,
                  style:
                      TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _order.payments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final payment = _order.payments[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(_paymentIcon(payment.method),
                          color: AppColors.primary, size: 20.sp),
                      title: Text(_paymentLabel(l10n, payment.method),
                          style: TextStyle(fontSize: 13.sp)),
                      trailing: Text(
                          'NT\$ ${payment.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _orderTypeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'dine_in':
        return l10n.dineIn;
      case 'takeout':
        return l10n.takeout;
      case 'delivery':
        return l10n.delivery;
      default:
        return type;
    }
  }

  IconData _paymentIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.money;
      case 'credit_card':
        return Icons.credit_card;
      case 'line_pay':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  String _paymentLabel(AppLocalizations l10n, String method) {
    switch (method) {
      case 'cash':
        return l10n.cash;
      case 'credit_card':
        return l10n.creditCard;
      case 'line_pay':
        return 'LINE Pay';
      default:
        return method;
    }
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _TotalRow(
      {required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: isBold ? 15.sp : 13.sp,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: isBold ? 16.sp : 13.sp,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? AppColors.primary : AppColors.textSecondary)),
      ],
    );
  }
}
