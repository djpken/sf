import '../models/menu_category.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/payment.dart';
import '../models/table.dart';

class DemoData {
  static final DateTime _now = DateTime.now();
  static final DateTime _createdAt = DateTime(2026, 5, 14, 9);

  static List<MenuCategory> get categories => [
        _category('cat-signature', '招牌套餐', 0),
        _category('cat-main', '主餐', 1),
        _category('cat-drinks', '飲品', 2),
        _category('cat-dessert', '甜點', 3),
      ];

  static List<MenuItem> get menuItems => [
        _item('item-001', 'cat-signature', '炙燒牛排飯', 280, '附湯與今日小菜'),
        _item('item-002', 'cat-signature', '椒麻雞腿套餐', 240, '微辣，附白飯'),
        _item('item-003', 'cat-signature', '海鮮義大利麵', 260, '蝦仁、蛤蜊、番茄醬汁'),
        _item('item-004', 'cat-signature', '雙人分享盤', 520, '炸物、沙拉、主廚小點'),
        _item('item-005', 'cat-main', '經典牛肉堡', 220, '可加起司或培根'),
        _item('item-006', 'cat-main', '香煎鮭魚排', 320, '附時蔬'),
        _item('item-007', 'cat-main', '松露野菇燉飯', 250, '奶素可'),
        _item('item-008', 'cat-main', '塔香三杯雞', 230, '下飯熱銷'),
        _item('item-009', 'cat-drinks', '冷萃咖啡', 120, '中焙豆'),
        _item('item-010', 'cat-drinks', '蜂蜜檸檬氣泡飲', 110, '固定甜度'),
        _item('item-011', 'cat-drinks', '伯爵鮮奶茶', 130, '可調甜度'),
        _item('item-012', 'cat-drinks', '芭樂青茶', 95, '台灣茶底'),
        _item('item-013', 'cat-dessert', '焦糖布丁', 90, '每日限量'),
        _item('item-014', 'cat-dessert', '巴斯克乳酪蛋糕', 140, '濃郁奶香'),
        _item('item-015', 'cat-dessert', '季節水果塔', 160, '依當日水果調整'),
        _item('item-016', 'cat-dessert', '巧克力布朗尼', 120, '附鮮奶油'),
      ];

  static List<MenuItem> menuItemsForCategory(String categoryId) {
    return menuItems.where((item) => item.categoryId == categoryId).toList();
  }

  static List<TableModel> get tables => [
        _table('table-a01', 'A01', 2, '窗邊', 'available'),
        _table('table-a02', 'A02', 4, '窗邊', 'occupied'),
        _table('table-a03', 'A03', 4, '窗邊', 'available'),
        _table('table-b01', 'B01', 2, '吧台', 'reserved'),
        _table('table-b02', 'B02', 2, '吧台', 'available'),
        _table('table-c01', 'C01', 6, '包廂', 'occupied'),
        _table('table-c02', 'C02', 8, '包廂', 'available'),
        _table('table-d01', 'D01', 4, '戶外', 'reserved'),
        _table('table-d02', 'D02', 4, '戶外', 'available'),
        _table('table-d03', 'D03', 2, '戶外', 'occupied'),
      ];

  static List<TableModel> get availableTables {
    return tables.where((table) => table.status == 'available').toList();
  }

  static List<Order> get orders => [
        _order(
          id: 'order-1008',
          number: '1008',
          type: 'dine_in',
          status: 'preparing',
          tableId: 'table-a02',
          tableName: 'A02',
          minutesAgo: 8,
          items: [
            _orderItem('order-1008', '炙燒牛排飯', 1, 280),
            _orderItem('order-1008', '伯爵鮮奶茶', 2, 130),
          ],
        ),
        _order(
          id: 'order-1007',
          number: '1007',
          type: 'takeout',
          status: 'ready',
          minutesAgo: 16,
          items: [
            _orderItem('order-1007', '經典牛肉堡', 2, 220),
            _orderItem('order-1007', '蜂蜜檸檬氣泡飲', 2, 110),
          ],
        ),
        _order(
          id: 'order-1006',
          number: '1006',
          type: 'delivery',
          status: 'pending',
          minutesAgo: 4,
          items: [
            _orderItem('order-1006', '海鮮義大利麵', 1, 260),
            _orderItem('order-1006', '巴斯克乳酪蛋糕', 1, 140),
          ],
        ),
        _order(
          id: 'order-1005',
          number: '1005',
          type: 'dine_in',
          status: 'completed',
          tableId: 'table-c01',
          tableName: 'C01',
          minutesAgo: 48,
          items: [
            _orderItem('order-1005', '雙人分享盤', 1, 520),
            _orderItem('order-1005', '冷萃咖啡', 2, 120),
          ],
          paid: true,
        ),
      ];

  static Map<String, dynamic> get reportSummary => {
        'total_revenue': 28640,
        'order_count': 86,
        'average_order_value': 333,
        'active_tables': 3,
        'pending_orders': 4,
      };

  static List<Map<String, dynamic>> get productRanking => [
        {'item_name': '炙燒牛排飯', 'total_quantity': 28, 'total_revenue': 7840},
        {'item_name': '經典牛肉堡', 'total_quantity': 23, 'total_revenue': 5060},
        {'item_name': '伯爵鮮奶茶', 'total_quantity': 35, 'total_revenue': 4550},
        {'item_name': '椒麻雞腿套餐', 'total_quantity': 16, 'total_revenue': 3840},
        {'item_name': '巴斯克乳酪蛋糕', 'total_quantity': 21, 'total_revenue': 2940},
      ];

  static Order createOrder({
    required String orderType,
    String? tableId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) {
    final orderId = 'demo-${_now.millisecondsSinceEpoch}';
    final orderItems = items.map((payload) {
      final menuItem = menuItems.firstWhere(
        (item) => item.id == payload['item_id'],
        orElse: () => menuItems.first,
      );
      final quantity = (payload['quantity'] as num?)?.toInt() ?? 1;
      return _orderItem(orderId, menuItem.name, quantity, menuItem.price,
          itemId: menuItem.id);
    }).toList();
    TableModel? table;
    if (tableId != null) {
      final tableIndex =
          tables.indexWhere((candidate) => candidate.id == tableId);
      if (tableIndex >= 0) table = tables[tableIndex];
    }

    return _order(
      id: orderId,
      number: _now.millisecondsSinceEpoch.toString().substring(8),
      type: orderType,
      status: 'pending',
      tableId: table?.id,
      tableName: table?.tableNumber,
      minutesAgo: 0,
      items: orderItems,
      notes: notes,
    );
  }

  static Order markPaid(Order order,
      {String method = 'cash', double? amount, String? referenceNumber}) {
    final payment = Payment(
      id: 'payment-${order.id}',
      orderId: order.id,
      method: method,
      amount: amount ?? order.total,
      referenceNumber: referenceNumber,
      createdAt: DateTime.now(),
    );

    return Order(
      id: order.id,
      storeId: order.storeId,
      tableId: order.tableId,
      tableName: order.tableName,
      orderNumber: order.orderNumber,
      orderType: order.orderType,
      status: 'completed',
      customerCount: order.customerCount,
      items: order.items,
      subtotal: order.subtotal,
      tax: order.tax,
      total: order.total,
      payments: [payment],
      notes: order.notes,
      createdAt: order.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static MenuCategory _category(String id, String name, int order) {
    return MenuCategory(
      id: id,
      storeId: 'store-demo',
      name: name,
      displayOrder: order,
      isActive: true,
      createdAt: _createdAt,
      updatedAt: _createdAt,
    );
  }

  static MenuItem _item(String id, String categoryId, String name, double price,
      String description) {
    return MenuItem(
      id: id,
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      isAvailable: true,
      displayOrder: int.parse(id.substring(id.length - 3)),
      createdAt: _createdAt,
      updatedAt: _createdAt,
    );
  }

  static TableModel _table(
      String id, String number, int capacity, String area, String status) {
    return TableModel(
      id: id,
      storeId: 'store-demo',
      tableNumber: number,
      capacity: capacity,
      area: area,
      status: status,
      createdAt: _createdAt,
      updatedAt: _createdAt,
    );
  }

  static Order _order({
    required String id,
    required String number,
    required String type,
    required String status,
    required int minutesAgo,
    required List<OrderItem> items,
    String? tableId,
    String? tableName,
    String? notes,
    bool paid = false,
  }) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final tax = subtotal * 0.05;
    final total = subtotal + tax;
    final createdAt = DateTime.now().subtract(Duration(minutes: minutesAgo));
    final order = Order(
      id: id,
      storeId: 'store-demo',
      tableId: tableId,
      tableName: tableName,
      orderNumber: number,
      orderType: type,
      status: status,
      customerCount: type == 'dine_in' ? 2 : null,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      payments: const [],
      notes: notes,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    return paid ? markPaid(order, amount: total) : order;
  }

  static OrderItem _orderItem(
    String orderId,
    String name,
    int quantity,
    double price, {
    String? itemId,
  }) {
    return OrderItem(
      id: '$orderId-$name',
      orderId: orderId,
      itemId: itemId,
      itemName: name,
      quantity: quantity,
      price: price,
      subtotal: price * quantity,
    );
  }
}
