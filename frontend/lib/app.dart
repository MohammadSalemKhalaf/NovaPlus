import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_navigator.dart';
import 'core/state/auth_state.dart';
import 'core/state/theme_state.dart';
import 'features/auth/domain/entities/login_credentials_entity.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'features/guest/presentation/screens/guest_shell_screen.dart';
import 'features/sales_agent/presentation/screens/sales_agent_shell_screen.dart';
import 'features/stores/presentation/screens/owner_shell_screen.dart';
import 'shared/theme/app_theme.dart';

class NovaPlusApp extends StatelessWidget {
  const NovaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeState>(
      builder: (context, themeState, _) => MaterialApp(
        title: 'NovaPlus Frontend',
        navigatorKey: AppNavigator.navigatorKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeState.themeMode,
        home: const _AppRootByAuthState(),
      ),
    );
  }
}

class _AppRootByAuthState extends StatelessWidget {
  const _AppRootByAuthState();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthState>(
      builder: (context, authState, _) {
        if (!authState.initialized) {
          return Scaffold(
            backgroundColor: const Color(0xFF080812),
            body: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A4EFF), Color(0xFF2E7BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (!authState.isAuthenticated) {
          return const LoginScreen(loginType: LoginType.endUser);
        }

        final role = authState.role;
        if (role == 'owner' || role == 'store_owner') {
          return const OwnerShellScreen();
        }
        if (role == 'admin' || role == 'super_admin') {
          return const AdminDashboardScreen();
        }
        if (role == 'sales_agent') {
          return const SalesAgentShellScreen();
        }
        if (role == 'end_user') {
          return const GuestShellScreen();
        }

        return const GuestShellScreen();
      },
    );
  }
}
