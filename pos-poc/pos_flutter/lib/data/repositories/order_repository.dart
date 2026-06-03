import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../demo/demo_data.dart';
import '../models/order.dart';

class OrderRepository {
  final ApiClient _apiClient;
  final List<Order> _demoOrders = List<Order>.from(DemoData.orders);

  OrderRepository(this._apiClient);

  // Create order
  Future<Order> createOrder({
    required String orderType,
    String? tableId,
    int? customerCount,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '/orders',
        data: {
          'order_type': orderType,
          if (tableId != null) 'table_id': tableId,
          if (customerCount != null) 'customer_count': customerCount,
          'items': items,
          if (notes != null) 'notes': notes,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (_) {
      final order = DemoData.createOrder(
        orderType: orderType,
        tableId: tableId,
        items: items,
        notes: notes,
      );
      _demoOrders.insert(0, order);
      return order;
    }
  }

  // Get order by ID
  Future<Order> getOrder(String id) async {
    try {
      final response = await _apiClient.get('/orders/$id');
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (e) {
      final index = _demoOrders.indexWhere((order) => order.id == id);
      if (index >= 0) return _demoOrders[index];
      throw _handleError(e);
    }
  }

  // List orders
  Future<List<Order>> listOrders({
    String? status,
    String? orderType,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };
      if (status != null) queryParams['status'] = status;
      if (orderType != null) queryParams['order_type'] = orderType;

      final response =
          await _apiClient.get('/orders', queryParameters: queryParams);
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      return _demoOrders
          .where((order) {
            final statusMatches = status == null || order.status == status;
            final typeMatches =
                orderType == null || order.orderType == orderType;
            return statusMatches && typeMatches;
          })
          .take(limit)
          .toList();
    }
  }

  // Add item to order
  Future<Order> addItem(String orderId, Map<String, dynamic> item) async {
    try {
      final response = await _apiClient.post(
        '/orders/$orderId/items',
        data: item,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (e) {
      final index = _demoOrders.indexWhere((order) => order.id == orderId);
      if (index >= 0) return _demoOrders[index];
      throw _handleError(e);
    }
  }

  // Update order item
  Future<Order> updateItem(
      String orderId, String itemId, Map<String, dynamic> updates) async {
    try {
      final response = await _apiClient.put(
        '/orders/$orderId/items/$itemId',
        data: updates,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Remove item from order
  Future<Order> removeItem(String orderId, String itemId) async {
    try {
      final response =
          await _apiClient.delete('/orders/$orderId/items/$itemId');
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Update order status
  Future<Order> updateStatus(String orderId, String status) async {
    try {
      final response = await _apiClient.put(
        '/orders/$orderId/status',
        data: {'status': status},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (e) {
      final index = _demoOrders.indexWhere((order) => order.id == orderId);
      if (index >= 0) {
        final current = _demoOrders[index];
        final updated = Order(
          id: current.id,
          storeId: current.storeId,
          tableId: current.tableId,
          tableName: current.tableName,
          orderNumber: current.orderNumber,
          orderType: current.orderType,
          status: status,
          customerCount: current.customerCount,
          items: current.items,
          subtotal: current.subtotal,
          tax: current.tax,
          total: current.total,
          payments: current.payments,
          notes: current.notes,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
        );
        _demoOrders[index] = updated;
        return updated;
      }
      throw _handleError(e);
    }
  }

  // Add payment
  Future<Order> addPayment(
    String orderId, {
    required String method,
    required double amount,
    String? referenceNumber,
  }) async {
    try {
      final response = await _apiClient.post(
        '/orders/$orderId/payments',
        data: {
          'method': method,
          'amount': amount,
          if (referenceNumber != null) 'reference_number': referenceNumber,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (e) {
      final index = _demoOrders.indexWhere((order) => order.id == orderId);
      if (index >= 0) {
        final paid = DemoData.markPaid(
          _demoOrders[index],
          method: method,
          amount: amount,
          referenceNumber: referenceNumber,
        );
        _demoOrders[index] = paid;
        return paid;
      }
      throw _handleError(e);
    }
  }

  // Complete order
  Future<Order> completeOrder(String orderId) async {
    try {
      final response = await _apiClient.post('/orders/$orderId/complete');
      final data = response.data['data'] as Map<String, dynamic>;
      return Order.fromJson(data);
    } on DioException catch (e) {
      final index = _demoOrders.indexWhere((order) => order.id == orderId);
      if (index >= 0) {
        final completed = DemoData.markPaid(_demoOrders[index]);
        _demoOrders[index] = completed;
        return completed;
      }
      throw _handleError(e);
    }
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    try {
      await _apiClient.post('/orders/$orderId/cancel');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      if (data is Map && data['error'] != null) {
        return data['error'] as String;
      }
    }
    return error.message ?? 'Network error occurred';
  }
}
