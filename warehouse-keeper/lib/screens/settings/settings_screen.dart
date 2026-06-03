import 'package:flutter/material.dart';
import 'package:warehouse_keeper/models/tare_container.dart';
import 'package:warehouse_keeper/screens/settings/tare_container_manager.dart';
import 'package:warehouse_keeper/services/monthly_inventory_storage.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  MonthlyInventoryStorage? _storage;
  List<TareContainer> _tareContainers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTareContainers();
  }

  Future<void> _loadTareContainers() async {
    setState(() => _loading = true);
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    final containers = await storage.loadTareContainers();
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _tareContainers = containers;
      _loading = false;
    });
  }

  Future<void> _addTareContainer() async {
    final result = await showTareContainerDialog(
      context: context,
      title: '新增容器',
      confirmLabel: '新增',
    );
    if (result == null) return;
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    _storage = storage;
    await storage.addTareContainer(result.name, result.grams);
    await _loadTareContainers();
  }

  Future<void> _editTareContainer(TareContainer container) async {
    final result = await showTareContainerDialog(
      context: context,
      title: '編輯容器',
      confirmLabel: '儲存',
      initialName: container.name,
      initialGrams: container.grams,
    );
    if (result == null) return;
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    _storage = storage;
    await storage.updateTareContainer(
      TareContainer(
        id: container.id,
        name: result.name,
        grams: result.grams,
        isFavorite: container.isFavorite,
      ),
    );
    await _loadTareContainers();
  }

  Future<void> _deleteTareContainer(TareContainer container) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除容器'),
        content: Text('確定要刪除「${container.name}」？\n\n已保存品項的扣重備註不會被修改。'),
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
    if (confirmed != true) return;
    final storage = _storage ?? await MonthlyInventoryStorage.create();
    _storage = storage;
    await storage.deleteTareContainer(container.id);
    await _loadTareContainers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TareContainerManager(
                    containers: _tareContainers,
                    onAdd: _addTareContainer,
                    onEdit: _editTareContainer,
                    onDelete: _deleteTareContainer,
                  ),
                ],
              ),
      ),
    );
  }
}
