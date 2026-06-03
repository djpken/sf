import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../demo/demo_data.dart';
import '../../core/local_db/menu_cache.dart';
import '../models/menu_category.dart';
import '../models/menu_item.dart';

class MenuRepository {
  final ApiClient _apiClient;
  final MenuCache? _menuCache;

  MenuRepository(this._apiClient, {MenuCache? menuCache})
      : _menuCache = menuCache;

  // Get all categories
  Future<List<MenuCategory>> getCategories() async {
    try {
      final response = await _apiClient.get('/menu/categories');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      final categories = data
          .map((json) => MenuCategory.fromJson(json as Map<String, dynamic>))
          .toList();
      // Cache for offline use
      _menuCache?.saveCategories(categories).ignore();
      return categories;
    } on DioException catch (_) {
      // Fall back to local cache on network error
      if (_menuCache != null) {
        final cached = await _menuCache!.getCategories();
        if (cached.isNotEmpty) return cached;
      }
      return DemoData.categories;
    }
  }

  // Get category by ID
  Future<MenuCategory> getCategoryById(String id) async {
    try {
      final response = await _apiClient.get('/menu/categories/$id');
      final data = response.data['data'] as Map<String, dynamic>;
      return MenuCategory.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get all items (optional category filter)
  Future<List<MenuItem>> getItems({String? categoryId}) async {
    try {
      final queryParams =
          categoryId != null ? {'category_id': categoryId} : null;
      final response =
          await _apiClient.get('/menu/items', queryParameters: queryParams);
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      final items = data
          .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
          .toList();
      // Cache all items (no per-category partial writes to avoid stale data)
      if (categoryId == null && _menuCache != null) {
        _menuCache!.saveItems(items).ignore();
      }
      return items;
    } on DioException catch (_) {
      // Fall back to local cache on network error
      if (_menuCache != null) {
        final cached = await _menuCache!.getItems(categoryId: categoryId);
        if (cached.isNotEmpty) return cached;
      }
      return categoryId == null
          ? DemoData.menuItems
          : DemoData.menuItemsForCategory(categoryId);
    }
  }

  // Get item by ID
  Future<MenuItem> getItemById(String id) async {
    try {
      final response = await _apiClient.get('/menu/items/$id');
      final data = response.data['data'] as Map<String, dynamic>;
      return MenuItem.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Get items by category
  Future<List<MenuItem>> getItemsByCategory(String categoryId) async {
    try {
      final response =
          await _apiClient.get('/menu/categories/$categoryId/items');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      return data
          .map((json) => MenuItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Create category
  Future<MenuCategory> createCategory({
    required String name,
    String? description,
    int displayOrder = 0,
  }) async {
    try {
      final response = await _apiClient.post('/menu/categories', data: {
        'name': name,
        if (description != null) 'description': description,
        'sort_order': displayOrder,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      return MenuCategory.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Update category
  Future<MenuCategory> updateCategory(
    String id, {
    String? name,
    String? description,
    int? displayOrder,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.put('/menu/categories/$id', data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (displayOrder != null) 'sort_order': displayOrder,
        if (isActive != null) 'is_active': isActive,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      return MenuCategory.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Delete category
  Future<void> deleteCategory(String id) async {
    try {
      await _apiClient.delete('/menu/categories/$id');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Create item
  Future<MenuItem> createItem({
    required String categoryId,
    required String name,
    String? description,
    required double price,
    bool isActive = true,
    int displayOrder = 0,
  }) async {
    try {
      final response = await _apiClient.post('/menu/items', data: {
        'category_id': categoryId,
        'name': name,
        if (description != null) 'description': description,
        'price': price,
        'is_active': isActive,
        'sort_order': displayOrder,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      return MenuItem.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Update item
  Future<MenuItem> updateItem(
    String id, {
    String? categoryId,
    String? name,
    String? description,
    double? price,
    bool? isActive,
    int? displayOrder,
  }) async {
    try {
      final response = await _apiClient.put('/menu/items/$id', data: {
        if (categoryId != null) 'category_id': categoryId,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (isActive != null) 'is_active': isActive,
        if (displayOrder != null) 'sort_order': displayOrder,
      });
      final data = response.data['data'] as Map<String, dynamic>;
      return MenuItem.fromJson(data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Delete item
  Future<void> deleteItem(String id) async {
    try {
      await _apiClient.delete('/menu/items/$id');
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
