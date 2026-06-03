import 'package:flutter/material.dart';
import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/screens/inventory_menu_screen.dart';
import 'package:warehouse_keeper/screens/settings/settings_screen.dart';
import 'package:warehouse_keeper/settings/settings_access.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';

class StoreSelectionScreen extends StatelessWidget {
  const StoreSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('貳樓補給站'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '設定',
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                '選擇區域',
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
                  children: StoreArea.values.map((area) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _StoreAreaCard(area: area),
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

  Future<void> _openSettings(BuildContext context) async {
    final authorized = await showDialog<bool>(
      context: context,
      builder: (_) => const _AdminPinDialog(),
    );
    if (authorized != true || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

class _AdminPinDialog extends StatefulWidget {
  const _AdminPinDialog();

  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  String _pin = '';
  String? _errorText;

  void _appendDigit(String digit) {
    if (_pin.length >= SettingsAccess.adminPin.length) return;
    setState(() {
      _pin += digit;
      _errorText = null;
    });
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorText = null;
    });
  }

  void _submit() {
    if (_pin == SettingsAccess.adminPin) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _errorText = 'PIN 碼錯誤');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '輸入管理 PIN',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PinDots(length: _pin.length),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _errorText == null
                    ? const SizedBox(height: 28)
                    : Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorText!,
                          key: ValueKey(_errorText),
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              _PinKeypad(
                onDigit: _appendDigit,
                onDelete: _deleteDigit,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pin.length == SettingsAccess.adminPin.length
                          ? _submit
                          : null,
                      child: const Text('確認'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;

  const _PinDots({required this.length});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '已輸入 $length 碼',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(SettingsAccess.adminPin.length, (index) {
          final filled = index < length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppTheme.primary : AppTheme.cardBg,
              border: Border.all(
                color: filled ? AppTheme.primary : AppTheme.border,
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  const _PinKeypad({
    required this.onDigit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (final digit in row) ...[
                Expanded(
                  child: _PinKey(
                    label: digit,
                    onPressed: () => onDigit(digit),
                  ),
                ),
                if (digit != row.last) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Expanded(child: SizedBox(height: 56)),
            const SizedBox(width: 12),
            Expanded(
              child: _PinKey(
                label: '0',
                onPressed: () => onDigit('0'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PinKey(
                icon: Icons.backspace_outlined,
                tooltip: '刪除一碼',
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const _PinKey({
    this.label,
    this.icon,
    this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(
            label!,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          )
        : Icon(icon, size: 22);
    return SizedBox(
      height: 56,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.cardBg,
          foregroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
        ),
        child:
            tooltip == null ? child : Tooltip(message: tooltip!, child: child),
      ),
    );
  }
}

class _StoreAreaCard extends StatelessWidget {
  final StoreArea area;

  const _StoreAreaCard({required this.area});

  IconData get _icon {
    switch (area) {
      case StoreArea.front:
        return Icons.storefront;
      case StoreArea.back:
        return Icons.warehouse;
      case StoreArea.both:
        return Icons.domain;
    }
  }

  Color get _color {
    switch (area) {
      case StoreArea.front:
        return AppTheme.accent;
      case StoreArea.back:
        return AppTheme.primary;
      case StoreArea.both:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InventoryMenuScreen(storeArea: area),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
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
                area.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
