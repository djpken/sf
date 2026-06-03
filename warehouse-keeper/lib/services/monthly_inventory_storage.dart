import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_keeper/models/inventory_item.dart';
import 'package:warehouse_keeper/models/inventory_record.dart';
import 'package:warehouse_keeper/models/monthly_zone_template.dart';
import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/models/tare_container.dart';
import 'package:warehouse_keeper/services/warehouse_api_client.dart';

class MonthlyInventoryStorage {
  static const _apiBaseUrl = String.fromEnvironment('WAREHOUSE_API_BASE_URL');
  static const _apiToken = String.fromEnvironment('WAREHOUSE_API_TOKEN');

  final SharedPreferences? _prefs;
  final Uuid _uuid;
  final WarehouseApiClient? _api;

  bool get isRemote => _api != null;

  MonthlyInventoryStorage._(this._prefs, this._uuid, this._api);

  static Future<MonthlyInventoryStorage> create() async {
    if (_apiBaseUrl.isNotEmpty && _apiToken.isNotEmpty) {
      return MonthlyInventoryStorage._(
        null,
        const Uuid(),
        WarehouseApiClient(baseUrl: _apiBaseUrl, token: _apiToken),
      );
    }
    return MonthlyInventoryStorage._(
      await SharedPreferences.getInstance(),
      const Uuid(),
      null,
    );
  }

  static String recordKey(StoreArea storeArea, DateTime month) {
    return 'monthly_${storeArea.name}_${DateFormat('yyyy_MM').format(month)}';
  }

  static String templateKey(StoreArea storeArea) {
    return 'monthly_zone_templates_${storeArea.name}';
  }

  static String tareContainerKey() {
    return 'tare_containers';
  }

  Future<List<TareContainer>> loadTareContainers() async {
    if (_api != null) return _api.loadTareContainers();
    final json = _prefs!.getString(tareContainerKey());
    if (json == null) {
      final defaults = [
        TareContainer(
          id: _uuid.v4(),
          name: '大保鮮盒',
          grams: 314,
          isFavorite: true,
        ),
        TareContainer(
          id: _uuid.v4(),
          name: '小保鮮盒',
          grams: 204,
          isFavorite: true,
        ),
      ];
      await _saveTareContainers(defaults);
      return defaults;
    }
    return (jsonDecode(json) as List)
        .map((e) => TareContainer.fromJson(e))
        .toList();
  }

  Future<TareContainer> addTareContainer(String name, int grams) async {
    if (_api != null) return _api.addTareContainer(name, grams);
    final containers = await loadTareContainers();
    final container = TareContainer(
      id: _uuid.v4(),
      name: name,
      grams: grams,
    );
    containers.add(container);
    await _saveTareContainers(containers);
    return container;
  }

  Future<void> updateTareContainer(TareContainer updated) async {
    if (_api != null) return _api.updateTareContainer(updated);
    final containers = await loadTareContainers();
    final index =
        containers.indexWhere((container) => container.id == updated.id);
    if (index == -1) return;
    containers[index] = updated;
    await _saveTareContainers(containers);
  }

  Future<void> deleteTareContainer(String containerId) async {
    if (_api != null) return _api.deleteTareContainer(containerId);
    final containers = await loadTareContainers();
    containers.removeWhere((container) => container.id == containerId);
    await _saveTareContainers(containers);
  }

  Future<List<MonthlyZoneTemplate>> loadZoneTemplates(
    StoreArea storeArea,
  ) async {
    if (_api != null) return _api.loadZoneTemplates(storeArea);
    final json = _prefs!.getString(templateKey(storeArea));
    if (json == null) return [];
    return (jsonDecode(json) as List)
        .map((e) => MonthlyZoneTemplate.fromJson(e))
        .toList();
  }

  Future<MonthlyZoneTemplate> addZoneTemplate(
    StoreArea storeArea,
    String name,
  ) async {
    if (_api != null) return _api.addZoneTemplate(storeArea, name);
    final now = DateTime.now();
    final templates = await loadZoneTemplates(storeArea);
    final template = MonthlyZoneTemplate(
      id: _uuid.v4(),
      name: name,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    templates.add(template);
    await _saveZoneTemplates(storeArea, templates);
    return template;
  }

  Future<void> renameZoneTemplate(
    StoreArea storeArea,
    String templateId,
    String name,
  ) async {
    if (_api != null) {
      return _api.renameZoneTemplate(storeArea, templateId, name);
    }
    final templates = await loadZoneTemplates(storeArea);
    final index = templates.indexWhere((template) => template.id == templateId);
    if (index == -1) return;
    templates[index].name = name;
    templates[index].updatedAt = DateTime.now();
    await _saveZoneTemplates(storeArea, templates);
  }

  Future<void> deleteZoneTemplate(
    StoreArea storeArea,
    String templateId,
  ) async {
    if (_api != null) return _api.deleteZoneTemplate(storeArea, templateId);
    final templates = await loadZoneTemplates(storeArea);
    final index = templates.indexWhere((template) => template.id == templateId);
    if (index == -1) return;
    templates[index].isActive = false;
    templates[index].updatedAt = DateTime.now();
    await _saveZoneTemplates(storeArea, templates);
  }

  Future<MonthlyInventoryRecord> loadOrCreateRecord({
    required StoreArea storeArea,
    required DateTime month,
  }) async {
    if (_api != null) {
      return _api.loadOrCreateRecord(storeArea: storeArea, month: month);
    }
    final normalizedMonth = DateTime(month.year, month.month);
    final key = recordKey(storeArea, normalizedMonth);
    final json = _prefs!.getString(key);
    var templates = await loadZoneTemplates(storeArea);

    MonthlyInventoryRecord record;
    if (json == null) {
      record = MonthlyInventoryRecord(
        id: _uuid.v4(),
        storeArea: storeArea,
        date: normalizedMonth,
      );
    } else {
      record = MonthlyInventoryRecord.fromJson(jsonDecode(json));
      if (templates.isEmpty && record.zones.isNotEmpty) {
        templates = await _migrateTemplatesFromRecord(storeArea, record);
      }
    }

    final changed = _syncRecordZones(record, templates);
    if (json == null || changed) {
      await saveRecord(record);
    }
    return record;
  }

  Future<void> saveRecord(MonthlyInventoryRecord record) async {
    if (_api != null) {
      if (record.isCompleted) {
        await _api.completeRecord(record.id);
      }
      return;
    }
    await _prefs!.setString(
      recordKey(record.storeArea, record.date),
      jsonEncode(record.toJson()),
    );
  }

  Future<void> _saveZoneTemplates(
    StoreArea storeArea,
    List<MonthlyZoneTemplate> templates,
  ) async {
    await _prefs!.setString(
      templateKey(storeArea),
      jsonEncode(templates.map((template) => template.toJson()).toList()),
    );
  }

  Future<void> _saveTareContainers(List<TareContainer> containers) async {
    await _prefs!.setString(
      tareContainerKey(),
      jsonEncode(containers.map((container) => container.toJson()).toList()),
    );
  }

  Future<List<MonthlyZoneTemplate>> _migrateTemplatesFromRecord(
    StoreArea storeArea,
    MonthlyInventoryRecord record,
  ) async {
    final now = DateTime.now();
    final templates = record.zones
        .map(
          (zone) => MonthlyZoneTemplate(
            id: zone.id,
            name: zone.name,
            isActive: true,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
    await _saveZoneTemplates(storeArea, templates);
    return templates;
  }

  bool _syncRecordZones(
    MonthlyInventoryRecord record,
    List<MonthlyZoneTemplate> templates,
  ) {
    var changed = false;
    final zonesById = {for (final zone in record.zones) zone.id: zone};

    for (final template in templates) {
      final zone = zonesById[template.id];
      if (zone != null && zone.name != template.name) {
        zone.name = template.name;
        changed = true;
      }
      if (template.isActive && zone == null) {
        record.zones.add(InventoryZone(id: template.id, name: template.name));
        changed = true;
      }
    }

    final activeTemplateIds = templates
        .where((template) => template.isActive)
        .map((template) => template.id)
        .toSet();
    final templateIds = templates.map((template) => template.id).toSet();
    final before = record.zones.length;
    record.zones.removeWhere((zone) {
      if (zone.items.isNotEmpty) return false;
      if (!templateIds.contains(zone.id)) return false;
      return !activeTemplateIds.contains(zone.id);
    });

    return changed || before != record.zones.length;
  }

  Future<InventoryItem> createMonthlyItem(
    InventoryZone zone,
    InventoryItem item,
  ) async {
    if (_api != null) return _api.createMonthlyItem(zone.id, item);
    return item;
  }

  Future<InventoryItem> updateMonthlyItem(InventoryItem item) async {
    if (_api != null) return _api.updateMonthlyItem(item);
    return item;
  }

  Future<void> deleteMonthlyItem(InventoryItem item) async {
    if (_api != null) return _api.deleteMonthlyItem(item.id);
  }
}
