class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://localhost:8080/api/v1';

  // Storage Keys
  static const String keyToken = 'auth_token';
  static const String keyEmployeeId = 'employee_id';
  static const String keyEmployeeName = 'employee_name';
  static const String keyEmployeeRole = 'employee_role';
  static const String keyTenantId = 'tenant_id';
  static const String keyStoreId = 'store_id';
  static const String keyStoreName = 'store_name';

  // App Info
  static const String appName = 'POS System';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;

  // Order Types
  static const String orderTypeDineIn = 'dine_in';
  static const String orderTypeTakeout = 'takeout';
  static const String orderTypeDelivery = 'delivery';

  // Payment Methods
  static const String paymentMethodCash = 'cash';
  static const String paymentMethodCreditCard = 'credit_card';
  static const String paymentMethodLinePay = 'line_pay';

  // Order Status
  static const String orderStatusPending = 'pending';
  static const String orderStatusPreparing = 'preparing';
  static const String orderStatusReady = 'ready';
  static const String orderStatusCompleted = 'completed';
  static const String orderStatusCancelled = 'cancelled';

  // Table Status
  static const String tableStatusAvailable = 'available';
  static const String tableStatusOccupied = 'occupied';
  static const String tableStatusReserved = 'reserved';
}
