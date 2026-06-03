import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:warehouse_keeper/models/tare_container.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';

class TareContainerManager extends StatelessWidget {
  final List<TareContainer> containers;
  final VoidCallback onAdd;
  final ValueChanged<TareContainer> onEdit;
  final ValueChanged<TareContainer> onDelete;

  const TareContainerManager({
    super.key,
    required this.containers,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '容器管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (containers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                '尚未新增任何容器',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final container = containers[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(container.name),
                  subtitle: Text(
                    container.isFavorite
                        ? '${container.grams}g · 常用'
                        : '${container.grams}g',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: '編輯容器',
                        onPressed: () => onEdit(container),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.error,
                        ),
                        tooltip: '刪除容器',
                        onPressed: () => onDelete(container),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class TareContainerDraft {
  final String name;
  final int grams;

  const TareContainerDraft({
    required this.name,
    required this.grams,
  });
}

Future<TareContainerDraft?> showTareContainerDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? initialName,
  int? initialGrams,
}) {
  return showDialog<TareContainerDraft>(
    context: context,
    builder: (_) => _TareContainerDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialGrams: initialGrams,
    ),
  );
}

enum _TareWeightUnit { grams, kilograms }

class _TareContainerDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String? initialName;
  final int? initialGrams;

  const _TareContainerDialog({
    required this.title,
    required this.confirmLabel,
    this.initialName,
    this.initialGrams,
  });

  @override
  State<_TareContainerDialog> createState() => _TareContainerDialogState();
}

class _TareContainerDialogState extends State<_TareContainerDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  _TareWeightUnit _unit = _TareWeightUnit.grams;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _weightCtrl = TextEditingController(
      text: widget.initialGrams == null ? '' : widget.initialGrams.toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (name.isEmpty || weight == null || weight <= 0) return;
    final grams = _unit == _TareWeightUnit.grams
        ? weight.round()
        : (weight * 1000).round();
    if (grams <= 0) return;
    Navigator.pop(
      context,
      TareContainerDraft(name: name, grams: grams),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGramMode = _unit == _TareWeightUnit.grams;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '容器名稱'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            SegmentedButton<_TareWeightUnit>(
              segments: const [
                ButtonSegment(
                  value: _TareWeightUnit.grams,
                  label: Text('g'),
                ),
                ButtonSegment(
                  value: _TareWeightUnit.kilograms,
                  label: Text('kg'),
                ),
              ],
              selected: {_unit},
              onSelectionChanged: (selected) {
                setState(() => _unit = selected.single);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightCtrl,
              keyboardType: TextInputType.numberWithOptions(
                decimal: !isGramMode,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  isGramMode ? RegExp(r'^\d*') : RegExp(r'^\d*\.?\d*'),
                ),
              ],
              decoration: InputDecoration(
                labelText: '重量',
                suffixText: isGramMode ? 'g' : 'kg',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
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
