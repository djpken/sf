import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../demo/demo_data.dart';

class ReportRepository {
  final ApiClient _apiClient;

  ReportRepository(this._apiClient);

  Future<Map<String, dynamic>> getSummary() async {
    try {
      final response = await _apiClient.get('/reports/summary');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (_) {
      return DemoData.reportSummary;
    }
  }

  Future<Map<String, dynamic>> getDailySalesReport({String? date}) async {
    try {
      final queryParams = date != null ? {'date': date} : null;
      final response = await _apiClient.get('/reports/sales/daily',
          queryParameters: queryParams);
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (_) {
      return DemoData.reportSummary;
    }
  }

  Future<List<Map<String, dynamic>>> getProductRanking({int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        '/reports/products/ranking',
        queryParameters: {'limit': limit},
      );
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } on DioException catch (_) {
      return DemoData.productRanking.take(limit).toList();
    }
  }
}
