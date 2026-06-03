import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_keeper/models/inventory_item.dart';
import 'package:warehouse_keeper/models/inventory_record.dart';
import 'package:warehouse_keeper/models/tare_container.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';

class ZoneDetailScreen extends StatefulWidget {
  final InventoryZone zone;
  final List<TareContainer> tareContainers;
  final VoidCallback onSave;
  final Future<InventoryItem> Function(InventoryZone zone, InventoryItem item)?
      onCreateItem;
  final Future<InventoryItem> Function(InventoryItem item)? onUpdateItem;
  final Future<void> Function(InventoryItem item)? onDeleteItem;
  final Future<TareContainer> Function(TareContainer container)?
      onToggleTareFavorite;

  const ZoneDetailScreen({
    super.key,
    required this.zone,
    this.tareContainers = const [],
    required this.onSave,
    this.onCreateItem,
    this.onUpdateItem,
    this.onDeleteItem,
    this.onToggleTareFavorite,
  });

  @override
  State<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends State<ZoneDetailScreen> {
  final _uuid = const Uuid();

  Future<void> _addItem() async {
    final result = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        uuid: _uuid,
        tareContainers: widget.tareContainers,
        onToggleTareFavorite: widget.onToggleTareFavorite,
      ),
    );
    if (result != null) {
      final saved = widget.onCreateItem == null
          ? result
          : await widget.onCreateItem!(widget.zone, result);
      setState(() => widget.zone.items.add(saved));
      widget.onSave();
    }
  }

  Future<void> _editItem(int index) async {
    final result = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        uuid: _uuid,
        existing: widget.zone.items[index],
        tareContainers: widget.tareContainers,
        onToggleTareFavorite: widget.onToggleTareFavorite,
      ),
    );
    if (result != null) {
      final saved = widget.onUpdateItem == null
          ? result
          : await widget.onUpdateItem!(result);
      setState(() => widget.zone.items[index] = saved);
      widget.onSave();
    }
  }

  Future<bool> _deleteItem(int index) async {
    final item = widget.zone.items[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除品項'),
        content: Text('確定要刪除「${item.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (widget.onDeleteItem != null) {
        await widget.onDeleteItem!(item);
      }
      setState(() => widget.zone.items.removeAt(index));
      widget.onSave();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.zone.name),
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.accentSoft.withOpacity(0.75),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '共 ${widget.zone.itemCount} 項品項',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.zone.items.isEmpty
                ? _buildEmptyState()
                : _buildItemList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('新增品項'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: AppTheme.primary.withOpacity(0.22)),
          const SizedBox(height: 16),
          const Text(
            '尚未新增品項',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            '點擊下方「新增品項」開始記錄',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: widget.zone.items.length,
      itemBuilder: (ctx, i) {
        final item = widget.zone.items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _deleteItem(i),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            child: _ItemCard(
              item: item,
              index: i + 1,
              onEdit: () => _editItem(i),
            ),
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final InventoryItem item;
  final int index;
  final VoidCallback onEdit;

  const _ItemCard({
    required this.item,
    required this.index,
    required this.onEdit,
  });

  Color get _typeColor {
    switch (item.measurementType) {
      case MeasurementType.quantity:
        return AppTheme.accent;
      case MeasurementType.weight:
        return AppTheme.primary;
      case MeasurementType.volume:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentSoft.withOpacity(0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.measurementType.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: _typeColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatValue(item.value)} ${item.measurementType.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (item.note != null && item.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.note!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppTheme.primary, size: 20),
            onPressed: onEdit,
            tooltip: '編輯',
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}

class _AddItemSheet extends StatefulWidget {
  final Uuid uuid;
  final InventoryItem? existing;
  final List<TareContainer> tareContainers;
  final Future<TareContainer> Function(TareContainer container)?
      onToggleTareFavorite;

  const _AddItemSheet({
    required this.uuid,
    required this.tareContainers,
    required this.onToggleTareFavorite,
    this.existing,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _valueCtrl;
  late TextEditingController _noteCtrl;
  late ScrollController _noteScrollCtrl;
  late ScrollController _tareScrollCtrl;
  late MeasurementType _measurementType;
  late List<TareContainer> _tareContainers;
  final List<TareContainer> _appliedTareContainers = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _valueCtrl =
        TextEditingController(text: e != null ? _formatValue(e.value) : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _noteScrollCtrl = ScrollController();
    _tareScrollCtrl = ScrollController();
    _measurementType = e?.measurementType ?? MeasurementType.weight;
    _tareContainers = List.of(widget.tareContainers);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    _noteScrollCtrl.dispose();
    _tareScrollCtrl.dispose();
    super.dispose();
  }

  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
          RegExp(r'\.$'),
          '',
        );
  }

  void _deductTare(TareContainer container) {
    if (_measurementType != MeasurementType.weight) return;

    final grossWeight = double.tryParse(_valueCtrl.text.trim());
    if (grossWeight == null) return;

    final netWeight = grossWeight - container.kilograms;
    setState(() {
      _appliedTareContainers
          .removeWhere((applied) => applied.name == container.name);
      _appliedTareContainers.add(container);
      _valueCtrl.text = _formatValue(netWeight < 0 ? 0 : netWeight);
      _noteCtrl.text = _noteWithAppliedTares(_noteCtrl.text);
    });
  }

  String _noteWithAppliedTares(String baseNote) {
    final tarePrefixes =
        _appliedTareContainers.map((c) => '已扣除${c.name} ').toList();
    final existingLines = baseNote
        .split('\n')
        .map((line) => line.trim())
        .where((line) =>
            line.isNotEmpty &&
            !tarePrefixes.any((prefix) => line.startsWith(prefix)))
        .toList();

    existingLines.addAll(_appliedTareContainers.map((c) => c.note));
    return existingLines.join('\n');
  }

  Future<TareContainer> _toggleTareFavorite(TareContainer container) async {
    final localUpdate = container.copyWith(
      isFavorite: !container.isFavorite,
    );
    final updated = widget.onToggleTareFavorite == null
        ? localUpdate
        : await widget.onToggleTareFavorite!(container);
    if (!mounted) return updated;
    setState(() {
      final index = _tareContainers.indexWhere((c) => c.id == updated.id);
      if (index != -1) _tareContainers[index] = updated;
    });
    return updated;
  }

  Future<void> _showTareMenu() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('容器選單')),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _tareContainers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final container = _tareContainers[index];
                  return ListTile(
                    title: Text(container.name),
                    subtitle: Text('${container.grams}g'),
                    trailing: Icon(
                      container.isFavorite
                          ? Icons.star
                          : Icons.star_border_outlined,
                      color: container.isFavorite
                          ? AppTheme.warning
                          : AppTheme.textSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _deductTare(container);
                    },
                    onLongPress: () async {
                      final updated = await _toggleTareFavorite(container);
                      if (!mounted) return;
                      setDialogState(() {
                        _tareContainers[index] = updated;
                      });
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final valueText = _valueCtrl.text.trim();
    if (name.isEmpty || valueText.isEmpty) return;
    final value = double.tryParse(valueText);
    if (value == null || value < 0) return;
    final note = _noteWithAppliedTares(_noteCtrl.text);

    final item = InventoryItem(
      id: widget.existing?.id ?? widget.uuid.v4(),
      name: name,
      measurementType: _measurementType,
      value: value,
      note: note.isNotEmpty ? note : null,
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final favoriteTareContainers =
        _tareContainers.where((container) => container.isFavorite).toList();

    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isEdit ? '編輯品項' : '新增品項',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                autofocus: !isEdit,
                decoration: const InputDecoration(
                  labelText: '品項名稱 *',
                  hintText: '例：鮮奶、米、洗潔精',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              const Text(
                '計量方式',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: MeasurementType.values.map((t) {
                  final selected = _measurementType == t;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _measurementType = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: selected
                                ? null
                                : Border.all(color: AppTheme.border),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppTheme.accentSoft
                                      : AppTheme.textSecondary,
                                ),
                              ),
                              Text(
                                t.unit,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: selected
                                      ? AppTheme.accentSoft.withOpacity(0.75)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _valueCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: '數值 *',
                  hintText: '輸入${_measurementType.label}',
                  suffixText: _measurementType.unit,
                ),
                textInputAction: TextInputAction.next,
              ),
              if (_measurementType == MeasurementType.weight) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      '扣除容器',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.more_horiz),
                      tooltip: '容器選單',
                      onPressed: _tareContainers.isEmpty ? null : _showTareMenu,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_tareContainers.isEmpty)
                  const Text(
                    '尚未設定容器重量',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  )
                else if (favoriteTareContainers.isEmpty)
                  const Text(
                    '尚未設定常用容器',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 172),
                    child: GridView.builder(
                      controller: _tareScrollCtrl,
                      primary: false,
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 128,
                        mainAxisExtent: 58,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: favoriteTareContainers.length,
                      itemBuilder: (context, index) {
                        final container = favoriteTareContainers[index];
                        return OutlinedButton(
                          onPressed: () => _deductTare(container),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                container.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${container.grams}g',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _noteCtrl,
                scrollController: _noteScrollCtrl,
                keyboardType: TextInputType.multiline,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '備註（選填）',
                  hintText: '任何補充說明',
                ),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(isEdit ? '儲存修改' : '新增品項'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
