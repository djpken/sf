import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'local_database.dart';

/// Represents a pending order stored locally while offline.
class PendingOrder {
  final String localId;
  final String orderType;
  final String? tableId;
  final List<Map<String, dynamic>> items;
  final String? paymentMethod;
  final double? paymentAmount;
  final String? paymentReference;
  final DateTime createdAt;
  final int syncAttempts;

  const PendingOrder({
    required this.localId,
    required this.orderType,
    this.tableId,
    required this.items,
    this.paymentMethod,
    this.paymentAmount,
    this.paymentReference,
    required this.createdAt,
    this.syncAttempts = 0,
  });
}

/// Stores orders locally when the device is offline and provides
/// methods to retrieve and mark them as synced.
class OfflineOrderQueue {
  final LocalDatabase _localDb;
  final _uuid = const Uuid();

  OfflineOrderQueue(this._localDb);

  /// Enqueues a new order to be synced when online.
  Future<String> enqueue({
    required String orderType,
    String? tableId,
    required List<Map<String, dynamic>> items,
    String? paymentMethod,
    double? paymentAmount,
    String? paymentReference,
  }) async {
    final db = await _localDb.db;
    final localId = _uuid.v4();
    await db.insert('offline_orders', {
      'local_id': localId,
      'order_type': orderType,
      'table_id': tableId,
      'items_json': jsonEncode(items),
      'payment_method': paymentMethod,
      'payment_amount': paymentAmount,
      'payment_reference': paymentReference,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'sync_attempts': 0,
      'synced': 0,
    });
    return localId;
  }

  /// Returns all unsynced pending orders, ordered by creation time.
  Future<List<PendingOrder>> getPending() async {
    final db = await _localDb.db;
    final rows = await db.query(
      'offline_orders',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToOrder).toList();
  }

  /// Returns the total number of unsynced orders.
  Future<int> pendingCount() async {
    final db = await _localDb.db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM offline_orders WHERE synced = 0'),
    );
    return count ?? 0;
  }

  /// Marks an order as successfully synced.
  Future<void> markSynced(String localId) async {
    final db = await _localDb.db;
    await db.update(
      'offline_orders',
      {'synced': 1},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Updates the payment info for a queued offline order.
  Future<void> setPayment(
    String localId, {
    required String paymentMethod,
    required double paymentAmount,
    String? paymentReference,
  }) async {
    final db = await _localDb.db;
    await db.update(
      'offline_orders',
      {
        'payment_method': paymentMethod,
        'payment_amount': paymentAmount,
        'payment_reference': paymentReference,
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  /// Increments the sync attempt counter for an order.
  Future<void> incrementAttempts(String localId) async {
    final db = await _localDb.db;
    await db.rawUpdate(
      'UPDATE offline_orders SET sync_attempts = sync_attempts + 1 WHERE local_id = ?',
      [localId],
    );
  }

  PendingOrder _rowToOrder(Map<String, dynamic> row) {
    final itemsRaw = jsonDecode(row['items_json'] as String) as List<dynamic>;
    return PendingOrder(
      localId: row['local_id'] as String,
      orderType: row['order_type'] as String,
      tableId: row['table_id'] as String?,
      items: itemsRaw.cast<Map<String, dynamic>>(),
      paymentMethod: row['payment_method'] as String?,
      paymentAmount: (row['payment_amount'] as num?)?.toDouble(),
      paymentReference: row['payment_reference'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      syncAttempts: (row['sync_attempts'] as int?) ?? 0,
    );
  }
}
