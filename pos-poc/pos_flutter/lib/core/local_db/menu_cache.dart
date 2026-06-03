import 'package:sqflite/sqflite.dart';
import '../../data/models/menu_category.dart';
import '../../data/models/menu_item.dart';
import 'local_database.dart';

/// Caches menu categories and items in SQLite for offline access.
class MenuCache {
  final LocalDatabase _localDb;

  MenuCache(this._localDb);

  // ── Categories ─────────────────────────────────────────────────────────────

  Future<void> saveCategories(List<MenuCategory> categories) async {
    final db = await _localDb.db;
    final batch = db.batch();
    for (final cat in categories) {
      batch.insert(
        'menu_categories',
        {
          'id': cat.id,
          'store_id': cat.storeId,
          'name': cat.name,
          'description': cat.description,
          'display_order': cat.displayOrder,
          'is_active': cat.isActive ? 1 : 0,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<MenuCategory>> getCategories() async {
    final db = await _localDb.db;
    final rows = await db.query(
      'menu_categories',
      where: 'is_active = 1',
      orderBy: 'display_order ASC',
    );
    return rows.map(_rowToCategory).toList();
  }

  MenuCategory _rowToCategory(Map<String, dynamic> row) {
    return MenuCategory(
      id: row['id'] as String,
      storeId: (row['store_id'] as String?) ?? '',
      name: row['name'] as String,
      description: row['description'] as String?,
      displayOrder: (row['display_order'] as int?) ?? 0,
      isActive: (row['is_active'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
    );
  }

  // ── Items ───────────────────────────────────────────────────────────────────

  Future<void> saveItems(List<MenuItem> items) async {
    final db = await _localDb.db;
    final batch = db.batch();
    for (final item in items) {
      batch.insert(
        'menu_items',
        {
          'id': item.id,
          'category_id': item.categoryId,
          'name': item.name,
          'description': item.description,
          'price': item.price,
          'image_url': item.imageUrl,
          'is_available': item.isAvailable ? 1 : 0,
          'display_order': item.displayOrder,
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<MenuItem>> getItems({String? categoryId}) async {
    final db = await _localDb.db;
    final rows = await db.query(
      'menu_items',
      where: categoryId != null
          ? 'category_id = ? AND is_available = 1'
          : 'is_available = 1',
      whereArgs: categoryId != null ? [categoryId] : null,
      orderBy: 'display_order ASC',
    );
    return rows.map(_rowToItem).toList();
  }

  MenuItem _rowToItem(Map<String, dynamic> row) {
    return MenuItem(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      price: (row['price'] as num).toDouble(),
      imageUrl: row['image_url'] as String?,
      isAvailable: (row['is_available'] as int?) == 1,
      displayOrder: (row['display_order'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int),
    );
  }

  Future<bool> hasCache() async {
    final db = await _localDb.db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM menu_categories'),
    );
    return (count ?? 0) > 0;
  }

  // Suppress unused warning — kept for future use (e.g. cache invalidation)
  // ignore: unused_element
  Future<void> _clearAll() async {
    final db = await _localDb.db;
    await db.delete('menu_categories');
    await db.delete('menu_items');
  }
}
