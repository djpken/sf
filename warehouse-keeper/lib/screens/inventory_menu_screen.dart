import 'package:flutter/material.dart';
import 'package:warehouse_keeper/models/inventory_type.dart';
import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/screens/monthly_inventory/monthly_inventory_screen.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';

class InventoryMenuScreen extends StatelessWidget {
  final StoreArea storeArea;

  const InventoryMenuScreen({super.key, required this.storeArea});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${storeArea.label}盤點'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                '盤點類型',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: InventoryType.values.map((type) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InventoryTypeCard(
                        type: type,
                        storeArea: storeArea,
                        isAvailable: type == InventoryType.monthly,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryTypeCard extends StatelessWidget {
  final InventoryType type;
  final StoreArea storeArea;
  final bool isAvailable;

  const _InventoryTypeCard({
    required this.type,
    required this.storeArea,
    required this.isAvailable,
  });

  IconData get _icon {
    switch (type) {
      case InventoryType.monthly:
        return Icons.calendar_month;
      case InventoryType.weekly:
        return Icons.view_week;
      case InventoryType.daily:
        return Icons.today;
    }
  }

  Color get _color {
    switch (type) {
      case InventoryType.monthly:
        return AppTheme.primary;
      case InventoryType.weekly:
        return AppTheme.accent;
      case InventoryType.daily:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isAvailable
          ? () {
              if (type == InventoryType.monthly) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MonthlyInventoryScreen(storeArea: storeArea),
                  ),
                );
              }
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon, color: _color, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  type.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                child: isAvailable
                    ? const Icon(
                        Icons.chevron_right,
                        color: AppTheme.textSecondary,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
