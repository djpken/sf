import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_keeper/models/inventory_item.dart';
import 'package:warehouse_keeper/models/tare_container.dart';
import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/services/monthly_inventory_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('record keys use the selected month instead of the current month', () {
    expect(
      MonthlyInventoryStorage.recordKey(
        StoreArea.front,
        DateTime(2026, 5, 23),
      ),
      'monthly_front_2026_05',
    );

    expect(
      MonthlyInventoryStorage.recordKey(
        StoreArea.front,
        DateTime(2026, 4, 1),
      ),
      'monthly_front_2026_04',
    );
  });

  test('active zone templates are shared across months', () async {
    final storage = await MonthlyInventoryStorage.create();
    await storage.addZoneTemplate(StoreArea.front, '冷藏區');

    final may = await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 5),
    );
    final june = await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 6),
    );

    expect(may.zones.map((zone) => zone.name), ['冷藏區']);
    expect(june.zones.map((zone) => zone.name), ['冷藏區']);
    expect(june.zones.single.id, may.zones.single.id);
  });

  test('renaming a zone template keeps monthly item records', () async {
    final storage = await MonthlyInventoryStorage.create();
    final template = await storage.addZoneTemplate(StoreArea.front, '冷藏區');
    final may = await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 5),
    );
    may.zones.single.items.add(
      InventoryItem(
        id: 'milk',
        name: '鮮奶',
        measurementType: MeasurementType.quantity,
        value: 3,
      ),
    );
    await storage.saveRecord(may);

    await storage.renameZoneTemplate(StoreArea.front, template.id, '冰箱區');
    final reloaded = await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 5),
    );

    expect(reloaded.zones.single.name, '冰箱區');
    expect(reloaded.zones.single.items.single.name, '鮮奶');
  });

  test('soft-deleting a zone keeps historical items but skips new months',
      () async {
    final storage = await MonthlyInventoryStorage.create();
    final template = await storage.addZoneTemplate(StoreArea.front, '冷藏區');
    final may = await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 5),
    );
    may.zones.single.items.add(
      InventoryItem(
        id: 'milk',
        name: '鮮奶',
        measurementType: MeasurementType.quantity,
        value: 3,
      ),
    );
    await storage.saveRecord(may);

    await storage.deleteZoneTemplate(StoreArea.front, template.id);

    final historical = await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 5),
    );
    final future = await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 6),
    );

    expect(historical.zones.map((zone) => zone.name), ['冷藏區']);
    expect(historical.zones.single.items.single.name, '鮮奶');
    expect(future.zones, isEmpty);
  });

  test('tare containers seed default shared records on first load', () async {
    final storage = await MonthlyInventoryStorage.create();

    final containers = await storage.loadTareContainers();

    expect(containers.map((container) => container.name), [
      '大保鮮盒',
      '小保鮮盒',
    ]);
    expect(containers.map((container) => container.grams), [314, 204]);
    expect(containers.map((container) => container.isFavorite), [true, true]);
  });

  test('tare containers can be added updated and deleted', () async {
    final storage = await MonthlyInventoryStorage.create();

    final added = await storage.addTareContainer('湯桶', 850);
    await storage.updateTareContainer(
      TareContainer(id: added.id, name: '大湯桶', grams: 900),
    );
    await storage.deleteTareContainer(added.id);

    final containers = await storage.loadTareContainers();

    expect(containers.any((container) => container.name == '大湯桶'), isFalse);
    expect(containers.map((container) => container.name), [
      '大保鮮盒',
      '小保鮮盒',
    ]);
  });

  test('added tare containers start outside favorites', () async {
    final storage = await MonthlyInventoryStorage.create();

    await storage.addTareContainer('湯桶', 850);

    final containers = await storage.loadTareContainers();
    final added = containers.singleWhere((container) => container.name == '湯桶');
    expect(added.isFavorite, isFalse);
  });

  test('tare containers are shared across store areas', () async {
    final storage = await MonthlyInventoryStorage.create();

    await storage.addTareContainer('方盒', 150);

    await storage.loadOrCreateRecord(
      storeArea: StoreArea.front,
      month: DateTime(2026, 5),
    );
    await storage.loadOrCreateRecord(
      storeArea: StoreArea.back,
      month: DateTime(2026, 5),
    );

    final containers = await storage.loadTareContainers();
    expect(containers.any((container) => container.name == '方盒'), isTrue);
  });
}
