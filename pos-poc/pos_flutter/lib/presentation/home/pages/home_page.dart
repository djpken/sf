import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/injection.dart';
import '../../../core/local_db/offline_order_queue.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../data/repositories/menu_repository.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../data/repositories/table_repository.dart';
import '../../../main.dart' show localeNotifier;
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../menu_mgmt/bloc/menu_mgmt_bloc.dart';
import '../../menu_mgmt/pages/menu_mgmt_page.dart';
import '../../orders/bloc/order_list_bloc.dart';
import '../../orders/bloc/order_list_event.dart';
import '../../orders/pages/orders_page.dart';
import '../../pos/bloc/cart_bloc.dart';
import '../../pos/bloc/menu_bloc.dart';
import '../../pos/pages/pos_page.dart';
import '../../reports/pages/reports_page.dart';
import '../../tables/bloc/table_bloc.dart';
import '../../tables/bloc/table_event.dart';
import '../../tables/pages/tables_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _toggleLanguage() {
    localeNotifier.value = localeNotifier.value.languageCode == 'zh'
        ? const Locale('en')
        : const Locale('zh');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => MenuBloc(getIt<MenuRepository>())),
        BlocProvider(
          create: (_) => CartBloc(
            getIt<OrderRepository>(),
            connectivity: getIt<ConnectivityService>(),
            offlineQueue: getIt<OfflineOrderQueue>(),
          ),
        ),
        BlocProvider(
            create: (_) => OrderListBloc(getIt<OrderRepository>())
              ..add(const LoadOrders())),
        BlocProvider(
            create: (_) =>
                TableBloc(getIt<TableRepository>())..add(const LoadTables())),
        BlocProvider(create: (_) => MenuMgmtBloc(getIt<MenuRepository>())),
      ],
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              backgroundColor: AppColors.surface,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
              unselectedIconTheme:
                  const IconThemeData(color: AppColors.textSecondary),
              unselectedLabelTextStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
              labelType: NavigationRailLabelType.all,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.point_of_sale),
                  label: Text('POS'),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.receipt_long),
                  label: Text(l10n.navOrders),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.table_restaurant),
                  label: Text(l10n.navTables),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.analytics),
                  label: Text(l10n.navReports),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.restaurant_menu),
                  label: Text(l10n.navMenu),
                ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 16.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            return Column(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    state.employee?.name
                                            .substring(0, 1)
                                            .toUpperCase() ??
                                        'U',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  state.employee?.name ?? '',
                                  style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          },
                        ),
                        SizedBox(height: 8.h),
                        // Language toggle
                        ValueListenableBuilder<Locale>(
                          valueListenable: localeNotifier,
                          builder: (context, locale, _) {
                            return TextButton(
                              onPressed: _toggleLanguage,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 4.h),
                                minimumSize: Size.zero,
                              ),
                              child: Text(
                                locale.languageCode == 'zh' ? 'EN' : '中',
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 4.h),
                        IconButton(
                          icon: const Icon(Icons.logout),
                          onPressed: () {
                            context
                                .read<AuthBloc>()
                                .add(const AuthLogoutRequested());
                          },
                          color: AppColors.error,
                          tooltip: l10n.logout,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const VerticalDivider(thickness: 1, width: 1),

            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  POSPage(),
                  OrdersPage(),
                  TablesPage(),
                  ReportsPage(),
                  MenuMgmtPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
