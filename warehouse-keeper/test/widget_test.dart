import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_keeper/main.dart';
import 'package:warehouse_keeper/models/inventory_item.dart';
import 'package:warehouse_keeper/models/tare_container.dart';
import 'package:warehouse_keeper/theme/app_theme.dart';
import 'package:warehouse_keeper/models/inventory_record.dart';
import 'package:warehouse_keeper/models/store_area.dart';
import 'package:warehouse_keeper/screens/monthly_inventory/monthly_inventory_screen.dart';
import 'package:warehouse_keeper/screens/monthly_inventory/zone_detail_screen.dart';
import 'package:warehouse_keeper/services/monthly_inventory_storage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());
    expect(find.text('貳樓補給站'), findsOneWidget);
  });

  testWidgets('Home copy omits operations supply sentence',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());

    expect(find.text('為每一次營運補給，留下清楚可靠的盤點紀錄。'), findsNothing);
  });

  testWidgets('Home does not show the brand mark icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Icon &&
            widget.icon == Icons.home_work_outlined &&
            widget.color == AppTheme.primary,
      ),
      findsNothing,
    );
  });

  testWidgets('Store area selector uses compact internal copy',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());

    expect(find.text('選擇區域'), findsOneWidget);
    expect(find.text('選擇盤點區域'), findsNothing);
    expect(find.text('請選擇本次要整理補給的店面區域'), findsNothing);
    expect(find.text('前場區域盤點'), findsNothing);
    expect(find.text('後場區域盤點'), findsNothing);
    expect(find.text('前後場區域盤點'), findsNothing);
  });

  testWidgets('Settings requires the admin PIN from the home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());

    expect(find.byTooltip('設定'), findsOneWidget);
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();

    expect(find.text('輸入管理 PIN'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('0').last);
    await tester.tap(find.text('0').last);
    await tester.tap(find.text('0').last);
    await tester.tap(find.text('0').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '確認'));
    await tester.pumpAndSettle();

    expect(find.text('PIN 碼錯誤'), findsOneWidget);
    expect(find.text('設定'), findsNothing);

    await tester.tap(find.byTooltip('刪除一碼'));
    await tester.tap(find.byTooltip('刪除一碼'));
    await tester.tap(find.byTooltip('刪除一碼'));
    await tester.tap(find.byTooltip('刪除一碼'));
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '確認'));
    await tester.pumpAndSettle();

    expect(find.text('設定'), findsOneWidget);
    expect(find.text('容器管理'), findsOneWidget);
  });

  testWidgets('Inventory types are shown daily weekly monthly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());

    await tester.tap(find.text('前場'));
    await tester.pumpAndSettle();

    final dailyTop = tester.getTopLeft(find.text('當日盤點')).dy;
    final weeklyTop = tester.getTopLeft(find.text('每週盤點')).dy;
    final monthlyTop = tester.getTopLeft(find.text('月底盤點')).dy;

    expect(dailyTop, lessThan(weeklyTop));
    expect(weeklyTop, lessThan(monthlyTop));
  });

  testWidgets('Inventory type menu uses compact internal copy',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());

    await tester.tap(find.text('前場'));
    await tester.pumpAndSettle();

    expect(find.text('盤點類型'), findsOneWidget);
    expect(find.text('前場 - 選擇盤點類型'), findsNothing);
    expect(find.text('選擇盤點類型'), findsNothing);
    expect(find.text('請選擇本次補給紀錄的盤點節奏'), findsNothing);
    expect(find.text('即將推出'), findsNothing);
    expect(find.text('當日臨時盤點'), findsNothing);
    expect(find.text('每週定期盤點'), findsNothing);
    expect(find.text('每月底進行的全面盤點'), findsNothing);
  });

  test('Measurement types are ordered weight quantity volume', () {
    expect(MeasurementType.values.map((type) => type.unit), ['kg', '個', 'L']);
  });

  testWidgets('Monthly inventory defaults to the current month',
      (WidgetTester tester) async {
    final now = DateTime.now();

    await tester.pumpWidget(
      const MaterialApp(
        home: MonthlyInventoryScreen(storeArea: StoreArea.front),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('yyyy年MM月').format(now)), findsOneWidget);
  });

  testWidgets('Selecting a month creates storage for that month',
      (WidgetTester tester) async {
    final target = DateTime(DateTime.now().year, 4);

    await tester.pumpWidget(
      const MaterialApp(
        home: MonthlyInventoryScreen(storeArea: StoreArea.front),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_month));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 月'));
    await tester.tap(find.text('套用'));
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('yyyy年MM月').format(target)), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.containsKey(
        MonthlyInventoryStorage.recordKey(StoreArea.front, target),
      ),
      isTrue,
    );
  });

  testWidgets('Zone manager opens add zone dialog without framework exceptions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MonthlyInventoryScreen(storeArea: StoreArea.front),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('區域管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增').last);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings container manager can add edit and delete containers',
      (WidgetTester tester) async {
    await tester.pumpWidget(const WarehouseKeeperApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('3').last);
    await tester.tap(find.text('4').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '確認'));
    await tester.pumpAndSettle();

    expect(find.text('容器管理'), findsOneWidget);
    expect(find.text('大保鮮盒'), findsOneWidget);

    await tester.tap(find.text('新增').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '容器名稱'), '湯桶');
    await tester.tap(find.text('kg'));
    await tester.enterText(find.widgetWithText(TextField, '重量'), '0.85');
    await tester.tap(find.widgetWithText(ElevatedButton, '新增'));
    await tester.pumpAndSettle();

    expect(find.text('湯桶'), findsOneWidget);
    expect(find.text('850g'), findsOneWidget);

    await tester.tap(find.byTooltip('編輯容器').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '容器名稱'), '大湯桶');
    await tester.enterText(find.widgetWithText(TextField, '重量'), '900');
    await tester.tap(find.text('g').last);
    await tester.tap(find.widgetWithText(ElevatedButton, '儲存'));
    await tester.pumpAndSettle();

    expect(find.text('大湯桶'), findsOneWidget);
    expect(find.text('900g'), findsOneWidget);

    await tester.tap(find.byTooltip('刪除容器').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, '刪除'));
    await tester.pumpAndSettle();

    expect(find.text('大湯桶'), findsNothing);
  });

  testWidgets('Monthly inventory no longer exposes full container manager',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MonthlyInventoryScreen(storeArea: StoreArea.front),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('容器管理'), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);
  });

  testWidgets('Monthly inventory zone cards do not expose delete actions',
      (WidgetTester tester) async {
    final storage = await MonthlyInventoryStorage.create();
    await storage.addZoneTemplate(StoreArea.front, '四門');

    await tester.pumpWidget(
      const MaterialApp(
        home: MonthlyInventoryScreen(storeArea: StoreArea.front),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('四門'), findsOneWidget);
    expect(find.byTooltip('刪除區域'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('new inventory items default to weight in kg',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    const tareContainers = [
      TareContainer(id: 'large-box', name: '大保鮮盒', grams: 314),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();

    expect(find.text('扣除容器'), findsOneWidget);
    expect(find.text('kg'), findsWidgets);

    await tester.enterText(find.byType(TextField).at(0), '鮮奶');
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.tap(find.widgetWithText(ElevatedButton, '新增品項'));
    await tester.pumpAndSettle();

    expect(zone.items.single.measurementType, MeasurementType.weight);
    expect(zone.items.single.value, 1);
  });

  testWidgets('inventory item cards delete by left swipe only',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區')
      ..items.add(
        InventoryItem(
          id: 'apple',
          name: '蘋果',
          measurementType: MeasurementType.quantity,
          value: 10,
        ),
      );
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          onSave: () => saved = true,
        ),
      ),
    );

    expect(find.text('蘋果'), findsOneWidget);
    expect(find.byTooltip('刪除'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.drag(find.text('蘋果'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('刪除品項'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '刪除'));
    await tester.pumpAndSettle();

    expect(find.text('蘋果'), findsNothing);
    expect(zone.items, isEmpty);
    expect(saved, isTrue);
  });

  testWidgets('weight items can deduct built-in container tare weights',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    const tareContainers = [
      TareContainer(
        id: 'large-box',
        name: '大保鮮盒',
        grams: 314,
        isFavorite: true,
      ),
      TareContainer(
        id: 'small-box',
        name: '小保鮮盒',
        grams: 204,
        isFavorite: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '鮮奶');

    expect(find.text('扣除容器'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.tap(find.text('大保鮮盒'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '0.686',
    );

    await tester.tap(find.text('小保鮮盒'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '0.482',
    );
    final noteField = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(noteField.maxLines, 3);
    expect(noteField.scrollController, isNotNull);

    await tester.enterText(find.byType(TextField).at(2), '冷藏庫');
    await tester.tap(find.widgetWithText(ElevatedButton, '新增品項'));
    await tester.pumpAndSettle();

    expect(zone.items.single.value, 0.482);
    expect(
      zone.items.single.note,
      '冷藏庫\n已扣除大保鮮盒 314g\n已扣除小保鮮盒 204g',
    );
  });

  testWidgets('container tare never creates negative weight',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    const tareContainers = [
      TareContainer(
        id: 'large-box',
        name: '大保鮮盒',
        grams: 314,
        isFavorite: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重量'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '0.1');
    await tester.tap(find.text('大保鮮盒'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '0',
    );
  });

  testWidgets('weight item tare buttons come from supplied containers',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    const tareContainers = [
      TareContainer(id: 'pail', name: '湯桶', grams: 850, isFavorite: true),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重量'));
    await tester.pumpAndSettle();

    expect(find.text('湯桶'), findsOneWidget);
    expect(find.text('大保鮮盒'), findsNothing);
    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.tap(find.text('湯桶'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '0.15',
    );
  });

  testWidgets('weight item only shows favorite tare buttons',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    const tareContainers = [
      TareContainer(
        id: 'favorite',
        name: '常用盒',
        grams: 100,
        isFavorite: true,
      ),
      TareContainer(id: 'hidden', name: '備用盒', grams: 200),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重量'));
    await tester.pumpAndSettle();

    expect(find.text('常用盒'), findsOneWidget);
    expect(find.text('備用盒'), findsNothing);
    expect(find.byTooltip('容器選單'), findsOneWidget);
  });

  testWidgets('long pressing container menu toggles tare favorite',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    final tareContainers = [
      const TareContainer(id: 'hidden', name: '備用盒', grams: 200),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
          onToggleTareFavorite: (container) async {
            final updated =
                container.copyWith(isFavorite: !container.isFavorite);
            tareContainers[0] = updated;
            return updated;
          },
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重量'));
    await tester.pumpAndSettle();

    expect(find.text('備用盒'), findsNothing);

    await tester.tap(find.byTooltip('容器選單'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('備用盒'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('備用盒'), findsOneWidget);
  });

  testWidgets('weight item tare list supports many containers',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    final tareContainers = List.generate(
      50,
      (index) => TareContainer(
        id: 'container-$index',
        name: '容器${index + 1}',
        grams: 100 + index,
        isFavorite: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重量'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), '1');
    await tester.tap(find.byTooltip('容器選單'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('容器50'),
      find.byType(ListView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('容器50'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '0.851',
    );
  });

  testWidgets('closing many-container tare sheet has no framework exceptions',
      (WidgetTester tester) async {
    final zone = InventoryZone(id: 'zone-1', name: '冷藏區');
    final tareContainers = List.generate(
      50,
      (index) => TareContainer(
        id: 'container-$index',
        name: '容器${index + 1}',
        grams: 100 + index,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ZoneDetailScreen(
          zone: zone,
          tareContainers: tareContainers,
          onSave: () {},
        ),
      ),
    );

    await tester.tap(find.text('新增品項'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重量'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
