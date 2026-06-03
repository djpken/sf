import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/constants/app_colors.dart';
import 'core/di/injection.dart';
import 'data/repositories/auth_repository.dart';
import 'presentation/auth/bloc/auth_bloc.dart';
import 'presentation/auth/bloc/auth_event.dart';
import 'presentation/auth/bloc/auth_state.dart';
import 'presentation/auth/pages/login_page.dart';
import 'presentation/home/pages/home_page.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final localeNotifier = ValueNotifier<Locale>(const Locale('zh'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1024, 768),
      minTextAdapt: true,
      builder: (context, child) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, locale, _) {
            return BlocProvider(
              create: (context) => AuthBloc(getIt<AuthRepository>())
                ..add(const AuthCheckRequested()),
              child: MaterialApp(
                title: 'POS System',
                debugShowCheckedModeBanner: false,
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColors.primary,
                    brightness: Brightness.light,
                  ),
                  useMaterial3: true,
                  scaffoldBackgroundColor: AppColors.background,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
                home: const AuthWrapper(),
              ),
            );
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthStatus.authenticated:
            return const HomePage();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const LoginPage();
        }
      },
    );
  }
}
