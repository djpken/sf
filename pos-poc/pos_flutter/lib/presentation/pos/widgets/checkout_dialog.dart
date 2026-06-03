import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/local_db/offline_order_queue.dart';
import '../../../core/utils/receipt_printer.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../core/di/injection.dart';

class CheckoutDialog extends StatefulWidget {
  final String orderId;
  final double totalAmount;

  const CheckoutDialog(
      {super.key, required this.orderId, required this.totalAmount});

  static Future<bool> show(
    BuildContext context, {
    required String orderId,
    required double totalAmount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CheckoutDialog(orderId: orderId, totalAmount: totalAmount),
    );
    return result ?? false;
  }

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _paymentMethod = 'cash';
  String _cashInput = '';
  String _referenceNo = '';
  bool _isProcessing = false;

  double get _cashReceived => double.tryParse(_cashInput) ?? 0;
  double get _change =>
      _paymentMethod == 'cash' ? (_cashReceived - widget.totalAmount) : 0;

  bool get _canConfirm {
    if (_paymentMethod == 'cash') return _cashReceived >= widget.totalAmount;
    return true;
  }

  void _appendCash(String digit) {
    if (digit == 'C') {
      setState(() => _cashInput = '');
    } else if (digit == '⌫') {
      if (_cashInput.isNotEmpty) {
        setState(
            () => _cashInput = _cashInput.substring(0, _cashInput.length - 1));
      }
    } else {
      setState(() => _cashInput += digit);
    }
  }

  Future<void> _confirm(AppLocalizations l10n) async {
    setState(() => _isProcessing = true);

    // Offline order: just record payment info in the queue and close.
    if (widget.orderId.startsWith('offline:')) {
      try {
        final localId = widget.orderId.substring('offline:'.length);
        await getIt<OfflineOrderQueue>().setPayment(
          localId,
          paymentMethod: _paymentMethod,
          paymentAmount: widget.totalAmount,
          paymentReference: _paymentMethod != 'cash' && _referenceNo.isNotEmpty
              ? _referenceNo
              : null,
        );
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        setState(() => _isProcessing = false);
      }
      return;
    }

    try {
      final repo = getIt<OrderRepository>();
      await repo.addPayment(
        widget.orderId,
        method: _paymentMethod,
        amount: widget.totalAmount,
        referenceNumber: _paymentMethod != 'cash' && _referenceNo.isNotEmpty
            ? _referenceNo
            : null,
      );
      final completedOrder = await repo.completeOrder(widget.orderId);

      // Offer to print receipt
      if (mounted) {
        final doPrint = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(l10n.checkoutCompleted),
            content: Text('${l10n.printReceipt}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.print),
                label: Text(l10n.printReceipt),
              ),
            ],
          ),
        );
        if (doPrint == true && mounted) {
          await ReceiptPrinter.printOrder(completedOrder);
        }
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.checkoutFailed(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.payment, color: AppColors.primary),
          SizedBox(width: 8.w),
          Text(l10n.checkoutTitle,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold)),
        ],
      ),
      contentPadding: EdgeInsets.all(20.w),
      content: SizedBox(
        width: 480.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount due
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  Text(l10n.amountDue,
                      style: TextStyle(
                          fontSize: 14.sp, color: AppColors.textSecondary)),
                  SizedBox(height: 4.h),
                  Text(
                    'NT\$ ${widget.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Payment method
            Text(l10n.paymentMethod,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
            SizedBox(height: 8.h),
            Row(
              children: [
                _PaymentMethodBtn(
                  label: l10n.cash,
                  icon: Icons.money,
                  value: 'cash',
                  selected: _paymentMethod == 'cash',
                  onTap: (v) => setState(() {
                    _paymentMethod = v;
                    _cashInput = '';
                  }),
                ),
                SizedBox(width: 8.w),
                _PaymentMethodBtn(
                  label: l10n.creditCard,
                  icon: Icons.credit_card,
                  value: 'credit_card',
                  selected: _paymentMethod == 'credit_card',
                  onTap: (v) => setState(() => _paymentMethod = v),
                ),
                SizedBox(width: 8.w),
                _PaymentMethodBtn(
                  label: 'LINE Pay',
                  icon: Icons.phone_android,
                  value: 'line_pay',
                  selected: _paymentMethod == 'line_pay',
                  onTap: (v) => setState(() => _paymentMethod = v),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Cash numpad
            if (_paymentMethod == 'cash') ...[
              Row(
                children: [
                  Expanded(child: _NumPad(onDigitTap: _appendCash)),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          label: l10n.cashReceived,
                          value:
                              'NT\$ ${_cashInput.isEmpty ? 0 : int.tryParse(_cashInput) ?? 0}',
                        ),
                        SizedBox(height: 8.h),
                        _InfoRow(
                          label: l10n.change,
                          value:
                              'NT\$ ${_change >= 0 ? _change.toStringAsFixed(0) : 0}',
                          highlight: _change >= 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            // Card/LinePay reference
            if (_paymentMethod != 'cash') ...[
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.referenceNumber,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                ),
                onChanged: (v) => setState(() => _referenceNo = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel,
              style:
                  TextStyle(fontSize: 14.sp, color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed:
              (_canConfirm && !_isProcessing) ? () => _confirm(l10n) : null,
          icon: _isProcessing
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(l10n.confirmCheckout, style: TextStyle(fontSize: 14.sp)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  const _PaymentMethodBtn({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
                color: selected ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : AppColors.textSecondary,
                  size: 20.sp),
              SizedBox(height: 4.h),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: selected ? Colors.white : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigitTap;

  const _NumPad({required this.onDigitTap});

  @override
  Widget build(BuildContext context) {
    const keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', 'C', '0', '⌫'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.6,
      mainAxisSpacing: 6.h,
      crossAxisSpacing: 6.w,
      children: keys
          .map((k) => GestureDetector(
                onTap: () => onDigitTap(k),
                child: Container(
                  decoration: BoxDecoration(
                    color: (k == 'C' || k == '⌫')
                        ? Colors.orange.shade50
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: Text(k,
                      style: TextStyle(
                          fontSize: 16.sp, fontWeight: FontWeight.bold)),
                ),
              ))
          .toList(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
