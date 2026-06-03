import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../demo/demo_data.dart';
import '../models/table.dart';

class TableRepository {
  final ApiClient _apiClient;

  TableRepository(this._apiClient);

  // Get all tables
  Future<List<TableModel>> getTables({String? area, String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (area != null) queryParams['area'] = area;
      if (status != null) queryParams['status'] = status;

      final response =
          await _apiClient.get('/tables', queryParameters: queryParams);
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map((json) => TableModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      return DemoData.tables.where((table) {
        final areaMatches = area == null || table.area == area;
        final statusMatches = status == null || table.status == status;
        return areaMatches && statusMatches;
      }).toList();
    }
  }

  // Get table by ID
  Future<TableModel> getTable(String id) async {
    try {
      final response = await _apiClient.get('/tables/$id');
      final data = response.data['data'] as Map<String, dynamic>;
      return TableModel.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get available tables
  Future<List<TableModel>> getAvailableTables({String? area}) async {
    try {
      final queryParams = area != null ? {'area': area} : null;
      final response = await _apiClient.get('/tables/available',
          queryParameters: queryParams);
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map((json) => TableModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (_) {
      return DemoData.availableTables
          .where((table) => area == null || table.area == area)
          .toList();
    }
  }

  // Update table status
  Future<void> updateTableStatus(String tableId, String status) async {
    try {
      await _apiClient.put(
        '/tables/$tableId/status',
        data: {'status': status},
      );
    } on DioException catch (_) {
      return;
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
