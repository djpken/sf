import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final SharedPreferences _prefs;

  SecureStorage._();
  static final SecureStorage _instance = SecureStorage._();
  factory SecureStorage() => _instance;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Token management
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: AppConstants.keyToken);
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: AppConstants.keyToken);
  }

  // Employee data
  Future<void> saveEmployeeId(String id) async {
    await _prefs.setString(AppConstants.keyEmployeeId, id);
  }

  Future<String?> getEmployeeId() async {
    return _prefs.getString(AppConstants.keyEmployeeId);
  }

  // Store data
  Future<void> saveStoreId(String id) async {
    await _prefs.setString(AppConstants.keyStoreId, id);
  }

  Future<String?> getStoreId() async {
    return _prefs.getString(AppConstants.keyStoreId);
  }

  Future<void> saveStoreName(String name) async {
    await _prefs.setString(AppConstants.keyStoreName, name);
  }

  Future<String?> getStoreName() async {
    return _prefs.getString(AppConstants.keyStoreName);
  }

  // Clear all data
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.clear();
  }
}
