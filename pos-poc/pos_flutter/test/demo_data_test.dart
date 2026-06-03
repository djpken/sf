import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/data/demo/demo_data.dart';

void main() {
  group('DemoData', () {
    test('provides a complete restaurant menu for POS demos', () {
      expect(DemoData.categories, hasLength(greaterThanOrEqualTo(4)));
      expect(DemoData.menuItems, hasLength(greaterThanOrEqualTo(12)));

      final firstCategory = DemoData.categories.first;
      final categoryItems = DemoData.menuItemsForCategory(firstCategory.id);

      expect(categoryItems, isNotEmpty);
      expect(categoryItems.every((item) => item.categoryId == firstCategory.id),
          isTrue);
    });

    test('provides tables across operational statuses', () {
      final statuses = DemoData.tables.map((table) => table.status).toSet();

      expect(statuses, containsAll(['available', 'occupied', 'reserved']));
      expect(DemoData.availableTables, isNotEmpty);
      expect(
          DemoData.availableTables
              .every((table) => table.status == 'available'),
          isTrue);
    });

    test('provides dashboard metrics and product ranking', () {
      expect(DemoData.reportSummary['total_revenue'], greaterThan(0));
      expect(DemoData.productRanking, hasLength(greaterThanOrEqualTo(5)));
      expect(DemoData.productRanking.first['total_revenue'], greaterThan(0));
    });
  });
}
