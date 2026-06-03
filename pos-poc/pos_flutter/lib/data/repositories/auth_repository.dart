import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../models/employee.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  AuthRepository(this._apiClient, this._secureStorage);

  // Email/Password login
  Future<Employee> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final token = response.data['data']['token'] as String;
      final employeeData =
          response.data['data']['employee'] as Map<String, dynamic>;
      final employee = Employee.fromJson(employeeData);

      // Save auth data
      await _secureStorage.saveToken(token);
      await _secureStorage.saveEmployeeId(employee.id);
      await _secureStorage.saveStoreId(employee.storeId);

      return employee;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // PIN login
  Future<Employee> pinLogin(String pin) async {
    try {
      final response = await _apiClient.post(
        '/auth/login/pin',
        data: {
          'pin': pin,
        },
      );

      final token = response.data['data']['token'] as String;
      final employeeData =
          response.data['data']['employee'] as Map<String, dynamic>;
      final employee = Employee.fromJson(employeeData);

      // Save auth data
      await _secureStorage.saveToken(token);
      await _secureStorage.saveEmployeeId(employee.id);
      await _secureStorage.saveStoreId(employee.storeId);

      return employee;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get current employee
  Future<Employee> getCurrentEmployee() async {
    try {
      final response = await _apiClient.get('/auth/me');
      final employeeData = response.data['data'] as Map<String, dynamic>;
      return Employee.fromJson(employeeData);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (e) {
      // Ignore errors on logout
    } finally {
      await _secureStorage.clearAll();
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.getToken();
    return token != null && token.isNotEmpty;
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
