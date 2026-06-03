import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:warehouse_keeper/models/inventory_item.dart';
import 'package:warehouse_keeper/models/inventory_record.dart';
import 'package:warehouse_keeper/models/monthly_zone_template.dart';
import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/models/tare_container.dart';

class WarehouseApiClient {
  final String baseUrl;
  final String token;
  final http.Client _client;

  WarehouseApiClient({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Future<List<MonthlyZoneTemplate>> loadZoneTemplates(
    StoreArea storeArea,
  ) async {
    final data = await _send(
      'GET',
      '/warehouse/zone-templates?store_area=${storeArea.name}',
    ) as List;
    return data.map((e) => _zoneTemplateFromJson(e)).toList();
  }

  Future<MonthlyZoneTemplate> addZoneTemplate(
    StoreArea storeArea,
    String name,
  ) async {
    final data = await _send(
      'POST',
      '/warehouse/zone-templates',
      body: {'store_area': storeArea.name, 'name': name},
    );
    return _zoneTemplateFromJson(data);
  }

  Future<void> renameZoneTemplate(
    StoreArea storeArea,
    String templateId,
    String name,
  ) async {
    await _send(
      'PUT',
      '/warehouse/zone-templates/$templateId',
      body: {'name': name},
    );
  }

  Future<void> deleteZoneTemplate(
      StoreArea storeArea, String templateId) async {
    await _send('DELETE', '/warehouse/zone-templates/$templateId');
  }

  Future<List<TareContainer>> loadTareContainers() async {
    final data = await _send('GET', '/warehouse/tare-containers') as List;
    return data.map((e) => _tareContainerFromJson(e)).toList();
  }

  Future<TareContainer> addTareContainer(String name, int grams) async {
    final data = await _send(
      'POST',
      '/warehouse/tare-containers',
      body: {'name': name, 'grams': grams},
    );
    return _tareContainerFromJson(data);
  }

  Future<void> updateTareContainer(TareContainer container) async {
    await _send(
      'PUT',
      '/warehouse/tare-containers/${container.id}',
      body: {'name': container.name, 'grams': container.grams},
    );
  }

  Future<void> deleteTareContainer(String id) async {
    await _send('DELETE', '/warehouse/tare-containers/$id');
  }

  Future<MonthlyInventoryRecord> loadOrCreateRecord({
    required StoreArea storeArea,
    required DateTime month,
  }) async {
    final yearMonth = DateFormat('yyyy-MM').format(month);
    final data = await _send(
      'GET',
      '/warehouse/monthly-records?store_area=${storeArea.name}&year_month=$yearMonth',
    );
    return _recordFromJson(data);
  }

  Future<void> completeRecord(String recordId) async {
    await _send('POST', '/warehouse/monthly-records/$recordId/complete');
  }

  Future<InventoryItem> createMonthlyItem(
    String zoneId,
    InventoryItem item,
  ) async {
    final data = await _send(
      'POST',
      '/warehouse/monthly-zones/$zoneId/items',
      body: _itemToJson(item),
    );
    return _itemFromJson(data);
  }

  Future<InventoryItem> updateMonthlyItem(InventoryItem item) async {
    final data = await _send(
      'PUT',
      '/warehouse/monthly-items/${item.id}',
      body: _itemToJson(item),
    );
    return _itemFromJson(data);
  }

  Future<void> deleteMonthlyItem(String itemId) async {
    await _send('DELETE', '/warehouse/monthly-items/$itemId');
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: _headers);
      case 'POST':
        response = await _client.post(
          uri,
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        );
      case 'PUT':
        response = await _client.put(
          uri,
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        );
      case 'DELETE':
        response = await _client.delete(uri, headers: _headers);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'Warehouse API request failed');
    }
    return decoded['data'];
  }

  MonthlyZoneTemplate _zoneTemplateFromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return MonthlyZoneTemplate(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  TareContainer _tareContainerFromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return TareContainer(
      id: map['id'],
      name: map['name'],
      grams: map['grams'],
    );
  }

  MonthlyInventoryRecord _recordFromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final storeArea = StoreArea.values.byName(map['store_area']);
    final record = MonthlyInventoryRecord(
      id: map['id'],
      storeArea: storeArea,
      date: DateTime.parse('${map['year_month']}-01'),
      zones: ((map['zones'] as List?) ?? [])
          .map(
            (zone) => InventoryZone(
              id: zone['id'],
              name: zone['name_snapshot'],
              items: ((zone['items'] as List?) ?? [])
                  .map((item) => _itemFromJson(item))
                  .toList(),
            ),
          )
          .toList(),
      isCompleted: map['is_completed'] ?? false,
    );
    return record;
  }

  InventoryItem _itemFromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return InventoryItem(
      id: map['id'],
      name: map['name'],
      measurementType: MeasurementType.values.byName(map['measurement_type']),
      value: (map['value'] as num).toDouble(),
      note: map['note'],
    );
  }

  Map<String, dynamic> _itemToJson(InventoryItem item) => {
        'name': item.name,
        'measurement_type': item.measurementType.name,
        'value': item.value,
        'note': item.note,
      };
}
