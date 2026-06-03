import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Manages the local SQLite database for offline support.
class LocalDatabase {
  static const _dbName = 'pos_offline.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Menu categories cache
    await db.execute('''
      CREATE TABLE menu_categories (
        id TEXT PRIMARY KEY,
        store_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        display_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Menu items cache
    await db.execute('''
      CREATE TABLE menu_items (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        image_url TEXT,
        is_available INTEGER DEFAULT 1,
        display_order INTEGER DEFAULT 0,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Offline order queue — orders to be synced when back online
    await db.execute('''
      CREATE TABLE offline_orders (
        local_id TEXT PRIMARY KEY,
        order_type TEXT NOT NULL,
        table_id TEXT,
        items_json TEXT NOT NULL,
        payment_method TEXT,
        payment_amount REAL,
        payment_reference TEXT,
        created_at INTEGER NOT NULL,
        sync_attempts INTEGER DEFAULT 0,
        synced INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
