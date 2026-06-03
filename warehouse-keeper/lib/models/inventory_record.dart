import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/models/inventory_item.dart';

class InventoryZone {
  final String id;
  String name;
  List<InventoryItem> items;

  InventoryZone({
    required this.id,
    required this.name,
    List<InventoryItem>? items,
  }) : items = items ?? [];

  int get itemCount => items.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory InventoryZone.fromJson(Map<String, dynamic> json) => InventoryZone(
        id: json['id'],
        name: json['name'],
        items: (json['items'] as List)
            .map((e) => InventoryItem.fromJson(e))
            .toList(),
      );
}

class MonthlyInventoryRecord {
  final String id;
  final StoreArea storeArea;
  final DateTime date;
  List<InventoryZone> zones;
  bool isCompleted;

  MonthlyInventoryRecord({
    required this.id,
    required this.storeArea,
    required this.date,
    List<InventoryZone>? zones,
    this.isCompleted = false,
  }) : zones = zones ?? [];

  int get totalItems => zones.fold(0, (sum, z) => sum + z.itemCount);

  Map<String, dynamic> toJson() => {
        'id': id,
        'storeArea': storeArea.name,
        'date': date.toIso8601String(),
        'zones': zones.map((e) => e.toJson()).toList(),
        'isCompleted': isCompleted,
      };

  factory MonthlyInventoryRecord.fromJson(Map<String, dynamic> json) =>
      MonthlyInventoryRecord(
        id: json['id'],
        storeArea: StoreArea.values.byName(json['storeArea']),
        date: DateTime.parse(json['date']),
        zones: (json['zones'] as List)
            .map((e) => InventoryZone.fromJson(e))
            .toList(),
        isCompleted: json['isCompleted'] ?? false,
      );
}
