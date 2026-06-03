import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/order.dart';

/// Generates and prints a thermal-style PDF receipt for a completed order.
///
/// Chinese character support requires adding a CJK TrueType font to
/// `assets/fonts/NotoSansSC-Regular.ttf` (or similar). If the font is absent,
/// item names that contain CJK characters will render as boxes; all structural
/// labels use ASCII-safe strings automatically.
class ReceiptPrinter {
  /// Print a receipt for the given [order].
  /// Opens the platform's print dialog.
  static Future<void> printOrder(Order order) async {
    final pdf = await _buildPdf(order);
    await Printing.layoutPdf(
      onLayout: (_) async => pdf,
      name: 'Receipt-${order.orderNumber}',
    );
  }

  static Future<Uint8List> _buildPdf(Order order) async {
    final doc = pw.Document();

    // Try to load a CJK font for proper Chinese rendering.
    pw.Font? cjkFont;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
      cjkFont = pw.Font.ttf(fontData);
    } catch (_) {
      // Font not found — CJK characters will fall back to boxes.
    }

    pw.TextStyle style(
      double size, {
      pw.FontWeight weight = pw.FontWeight.normal,
      PdfColor color = PdfColors.black,
    }) {
      return pw.TextStyle(
        font: cjkFont,
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
    }

    final dateStr =
        DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt.toLocal());
    final orderTypeLabel = _orderTypeLabel(order.orderType);
    final currency = NumberFormat('#,##0', 'en');

    // 80 mm wide thermal receipt (226 pt at 72dpi)
    const pageWidth = 226.0;
    const pageFormat = PdfPageFormat(pageWidth, double.infinity, marginAll: 8);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              pw.Center(
                child: pw.Text('POS Receipt',
                    style: style(14, weight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // Order meta
              _kv('Order #', order.orderNumber, style),
              _kv('Date', dateStr, style),
              _kv('Type', orderTypeLabel, style),
              if (order.tableName != null)
                _kv('Table', order.tableName!, style),
              pw.Divider(thickness: 0.5),

              // ── Items ────────────────────────────────────────────────────
              pw.Row(
                children: [
                  pw.Expanded(
                      child: pw.Text('Item',
                          style: style(8, weight: pw.FontWeight.bold))),
                  pw.Text('Qty', style: style(8, weight: pw.FontWeight.bold)),
                  pw.SizedBox(width: 8),
                  pw.SizedBox(
                    width: 48,
                    child: pw.Text('Amount',
                        style: style(8, weight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.3),
              ...order.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                            child: pw.Text(item.itemName, style: style(8))),
                        pw.Text('x${item.quantity}', style: style(8)),
                        pw.SizedBox(width: 8),
                        pw.SizedBox(
                          width: 48,
                          child: pw.Text(
                            'NT\$${currency.format(item.subtotal)}',
                            style: style(8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  )),
              pw.Divider(thickness: 0.5),

              // ── Totals ───────────────────────────────────────────────────
              _kv('Subtotal', 'NT\$${currency.format(order.subtotal)}', style),
              _kv('Tax', 'NT\$${currency.format(order.tax)}', style),
              pw.Divider(thickness: 0.3),
              _kv('TOTAL', 'NT\$${currency.format(order.total)}', style,
                  bold: true, size: 11),

              // ── Payment ──────────────────────────────────────────────────
              if (order.payments.isNotEmpty) ...[
                pw.Divider(thickness: 0.5),
                ...order.payments.map((p) => _kv(
                      _paymentLabel(p.method),
                      'NT\$${currency.format(p.amount)}',
                      style,
                    )),
              ],

              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Thank you!', style: style(9))),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _kv(
    String label,
    String value,
    pw.TextStyle Function(double, {pw.FontWeight weight, PdfColor color})
        style, {
    bool bold = false,
    double size = 8,
  }) {
    final weight = bold ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style(size, weight: weight)),
          pw.Text(value, style: style(size, weight: weight)),
        ],
      ),
    );
  }

  static String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine_in':
        return 'Dine In';
      case 'takeout':
        return 'Takeout';
      case 'delivery':
        return 'Delivery';
      default:
        return type;
    }
  }

  static String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'credit_card':
        return 'Credit Card';
      case 'line_pay':
        return 'LINE Pay';
      default:
        return method;
    }
  }
}
