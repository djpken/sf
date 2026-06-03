import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_keeper/models/inventory_record.dart';
import 'package:warehouse_keeper/models/monthly_zone_template.dart';
import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/models/tare_container.dart';
import 'package:warehouse_keeper/screens/monthly_inventory/zone_detail_screen.dart';
import 'package:warehouse_keeper/services/monthly_inventory_storage.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';

class MonthlyInventoryScreen extends StatefulWidget {
  final StoreArea storeArea;

  const MonthlyInventoryScreen({super.key, required this.storeArea});

  @override
  State<MonthlyInventoryScreen> createState() => _MonthlyInventoryScreenState();
}

class _MonthlyInventoryScreenState extends State<MonthlyInventoryScreen> {
  MonthlyInventoryRecord? _record;
  MonthlyInventoryStorage? _storage;
  List<MonthlyZoneTemplate> _zoneTemplates = [];
  List<TareContainer> _tareContainers = [];
  bool _loading = true;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadOrCreateRecord();
  }

  Future<void> _loadOrCreateRecord() async {
    setState(() => _loading = true);
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    final record = await storage.loadOrCreateRecord(
      storeArea: widget.storeArea,
      month: _selectedMonth,
    );
    final templates = await storage.loadZoneTemplates(widget.storeArea);
    final tareContainers = await storage.loadTareContainers();
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _record = record;
      _zoneTemplates = templates;
      _tareContainers = tareContainers;
      _loading = false;
    });
  }

  Future<void> _saveRecord() async {
    if (_record == null) return;
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    _storage = storage;
    await storage.saveRecord(_record!);
  }

  Future<void> _addZoneTemplate() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _ZoneNameDialog(
        title: '新增區域',
        confirmLabel: '新增',
        hintText: '例：A區、冷藏區、乾貨區',
      ),
    );
    if (result != null && result.isNotEmpty) {
      final storage = _storage ?? await MonthlyInventoryStorage.create();
      _storage = storage;
      await storage.addZoneTemplate(widget.storeArea, result);
      await _loadOrCreateRecord();
    }
  }

  Future<void> _renameZoneTemplate(MonthlyZoneTemplate template) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ZoneNameDialog(
        title: '重新命名區域',
        confirmLabel: '儲存',
        initialValue: template.name,
      ),
    );
    if (result == null || result.isEmpty || result == template.name) return;
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    _storage = storage;
    await storage.renameZoneTemplate(widget.storeArea, template.id, result);
    await _loadOrCreateRecord();
  }

  Future<void> _deleteZoneTemplate(MonthlyZoneTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除區域'),
        content: Text(
          '確定要刪除「${template.name}」？\n\n已有品項的月份會保留歷史資料，新月份不會再自動出現此區域。',
        ),
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
      final storage = _storage ?? await MonthlyInventoryStorage.create();
      _storage = storage;
      await storage.deleteZoneTemplate(widget.storeArea, template.id);
      await _loadOrCreateRecord();
    }
  }

  Future<TareContainer> _toggleTareContainerFavorite(
    TareContainer container,
  ) async {
    final updated = container.copyWith(isFavorite: !container.isFavorite);
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    _storage = storage;
    await storage.updateTareContainer(updated);
    await _loadOrCreateRecord();
    return updated;
  }

  Future<void> _selectMonth() async {
    var year = _selectedMonth.year;
    var month = _selectedMonth.month;
    final years = List.generate(11, (i) => DateTime.now().year - 5 + i);
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('選擇月份'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: year,
                  decoration: const InputDecoration(labelText: '年份'),
                  items: years
                      .map(
                        (y) => DropdownMenuItem(
                          value: y,
                          child: Text('$y 年'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => year = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (i) {
                    final value = i + 1;
                    return ChoiceChip(
                      label: Text('$value 月'),
                      selected: month == value,
                      onSelected: (_) {
                        setDialogState(() => month = value);
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, DateTime(year, month)),
              child: const Text('套用'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _selectedMonth = selected);
    await _loadOrCreateRecord();
  }

  Future<void> _showZoneManager() async {
    final action = await showModalBottomSheet<_ZoneManagerAction>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final activeTemplates =
            _zoneTemplates.where((template) => template.isActive).toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '區域管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(
                        ctx,
                        const _AddZoneManagerAction(),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (activeTemplates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '尚未新增任何區域',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: activeTemplates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final template = activeTemplates[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(template.name),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: '重新命名',
                                onPressed: () => Navigator.pop(
                                  ctx,
                                  _RenameZoneManagerAction(template),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.error,
                                ),
                                tooltip: '刪除',
                                onPressed: () => Navigator.pop(
                                  ctx,
                                  _DeleteZoneManagerAction(template),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    switch (action) {
      case _AddZoneManagerAction():
        await _addZoneTemplate();
      case _RenameZoneManagerAction(:final template):
        await _renameZoneTemplate(template);
      case _DeleteZoneManagerAction(:final template):
        await _deleteZoneTemplate(template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('yyyy年MM月').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('月底盤點 - ${widget.storeArea.label}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '區域管理',
            onPressed: _loading ? null : _showZoneManager,
          ),
          if (_record != null && _record!.zones.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: '完成盤點',
              onPressed: _completeInventory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(monthLabel),
                Expanded(
                  child: _record!.zones.isEmpty
                      ? _buildEmptyState()
                      : _buildZoneList(),
                ),
              ],
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _addZoneTemplate,
              icon: const Icon(Icons.add),
              label: const Text('新增區域'),
            ),
    );
  }

  Widget _buildHeader(String monthLabel) {
    return Container(
      color: AppTheme.accentSoft.withOpacity(0.75),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _selectMonth,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(monthLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.border),
                      backgroundColor: AppTheme.cardBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '共 ${_record!.zones.length} 個區域 · ${_record!.totalItems} 項品項',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (_record!.isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '已完成',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_view_rounded,
              size: 72, color: AppTheme.primary.withOpacity(0.22)),
          const SizedBox(height: 16),
          const Text(
            '尚未新增任何區域',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '點擊下方「新增區域」開始補給紀錄',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildZoneList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _record!.zones.length,
      itemBuilder: (ctx, i) {
        final zone = _record!.zones[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ZoneCard(
            zone: zone,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ZoneDetailScreen(
                    zone: zone,
                    tareContainers: _tareContainers,
                    onToggleTareFavorite: _toggleTareContainerFavorite,
                    onCreateItem: (zone, item) async {
                      final saved =
                          await _storage!.createMonthlyItem(zone, item);
                      if (_storage!.isRemote) await _loadOrCreateRecord();
                      return saved;
                    },
                    onUpdateItem: (item) async {
                      final saved = await _storage!.updateMonthlyItem(item);
                      if (_storage!.isRemote) await _loadOrCreateRecord();
                      return saved;
                    },
                    onDeleteItem: (item) async {
                      await _storage!.deleteMonthlyItem(item);
                      if (_storage!.isRemote) await _loadOrCreateRecord();
                    },
                    onSave: () => _saveRecord(),
                  ),
                ),
              );
              setState(() {});
              await _saveRecord();
            },
          ),
        );
      },
    );
  }

  Future<void> _completeInventory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認完成盤點'),
        content: Text(
            '共完成 ${_record!.zones.length} 個區域、${_record!.totalItems} 項品項的盤點。\n\n確定標記為完成？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認完成'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _record!.isCompleted = true);
      await _saveRecord();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('盤點已完成！'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }
}

sealed class _ZoneManagerAction {
  const _ZoneManagerAction();
}

class _AddZoneManagerAction extends _ZoneManagerAction {
  const _AddZoneManagerAction();
}

class _RenameZoneManagerAction extends _ZoneManagerAction {
  final MonthlyZoneTemplate template;

  const _RenameZoneManagerAction(this.template);
}

class _DeleteZoneManagerAction extends _ZoneManagerAction {
  final MonthlyZoneTemplate template;

  const _DeleteZoneManagerAction(this.template);
}

class _ZoneNameDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String? initialValue;
  final String? hintText;

  const _ZoneNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialValue,
    this.hintText,
  });

  @override
  State<_ZoneNameDialog> createState() => _ZoneNameDialogState();
}

class _ZoneNameDialogState extends State<_ZoneNameDialog> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _nameCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _nameCtrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: '區域名稱',
          hintText: widget.hintText,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final InventoryZone zone;
  final VoidCallback onTap;

  const _ZoneCard({
    required this.zone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.grid_view,
                  color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    zone.itemCount == 0
                        ? '尚未紀錄品項'
                        : '已紀錄 ${zone.itemCount} 項品項',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
