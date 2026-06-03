import 'dart:async';
import '../local_db/offline_order_queue.dart';
import '../network/connectivity_service.dart';
import '../../data/repositories/order_repository.dart';

/// Listens for connectivity restoration and uploads queued offline orders.
class SyncService {
  final OfflineOrderQueue _queue;
  final OrderRepository _orderRepository;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _sub;
  bool _syncing = false;

  SyncService(this._queue, this._orderRepository, this._connectivity);

  /// Start listening for connectivity changes and trigger sync on reconnect.
  void start() {
    _sub = _connectivity.onConnectivityChanged.listen((online) {
      if (online && !_syncing) {
        _sync();
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Manually trigger a sync attempt (e.g. on app foreground).
  Future<void> syncNow() async {
    if (!_connectivity.isOnline || _syncing) return;
    await _sync();
  }

  Future<void> _sync() async {
    _syncing = true;
    try {
      final pending = await _queue.getPending();
      for (final order in pending) {
        try {
          // Create order on server
          final created = await _orderRepository.createOrder(
            orderType: order.orderType,
            tableId: order.tableId,
            items: order.items,
          );

          // If payment was included, submit it too
          if (order.paymentMethod != null && order.paymentAmount != null) {
            await _orderRepository.addPayment(
              created.id,
              method: order.paymentMethod!,
              amount: order.paymentAmount!,
              referenceNumber: order.paymentReference,
            );
            await _orderRepository.updateStatus(created.id, 'completed');
          }

          await _queue.markSynced(order.localId);
        } catch (_) {
          await _queue.incrementAttempts(order.localId);
        }
      }
    } finally {
      _syncing = false;
    }
  }
}
