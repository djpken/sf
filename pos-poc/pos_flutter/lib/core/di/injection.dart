import 'package:get_it/get_it.dart';
import '../network/api_client.dart';
import '../network/connectivity_service.dart';
import '../storage/secure_storage.dart';
import '../local_db/local_database.dart';
import '../local_db/menu_cache.dart';
import '../local_db/offline_order_queue.dart';
import '../sync/sync_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/table_repository.dart';
import '../../data/repositories/report_repository.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Core
  final secureStorage = SecureStorage();
  await secureStorage.init();
  getIt.registerSingleton<SecureStorage>(secureStorage);

  getIt.registerSingleton<ApiClient>(ApiClient(secureStorage));

  // Connectivity
  final connectivityService = ConnectivityService();
  await connectivityService.init();
  getIt.registerSingleton<ConnectivityService>(connectivityService);

  // Local DB
  final localDatabase = LocalDatabase();
  getIt.registerSingleton<LocalDatabase>(localDatabase);

  getIt.registerLazySingleton<MenuCache>(
    () => MenuCache(getIt<LocalDatabase>()),
  );
  getIt.registerLazySingleton<OfflineOrderQueue>(
    () => OfflineOrderQueue(getIt<LocalDatabase>()),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<ApiClient>(), getIt<SecureStorage>()),
  );
  getIt.registerLazySingleton<MenuRepository>(
    () => MenuRepository(getIt<ApiClient>(), menuCache: getIt<MenuCache>()),
  );
  getIt.registerLazySingleton<OrderRepository>(
    () => OrderRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<TableRepository>(
    () => TableRepository(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ReportRepository>(
    () => ReportRepository(getIt<ApiClient>()),
  );

  // Sync service — start listening for reconnect events
  final syncService = SyncService(
    getIt<OfflineOrderQueue>(),
    getIt<OrderRepository>(),
    getIt<ConnectivityService>(),
  );
  syncService.start();
  getIt.registerSingleton<SyncService>(syncService);
}
