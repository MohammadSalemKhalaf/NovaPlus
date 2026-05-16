import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/state/store_cubit.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../guest/presentation/screens/guest_shell_screen.dart';
import '../../../stores/presentation/screens/owner_shell_screen.dart';
import '../../data/datasources/sales_agent_remote_data_source.dart';
import '../../data/repositories/sales_agent_repository_impl.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../cubit_or_bloc/sales_agent_cubit.dart';
import '../cubit_or_bloc/sales_agent_update_profile_cubit.dart';
import 'sales_agent_activation_code_screen.dart';
import 'sales_agent_dashboard_screen.dart';
import 'sales_agent_onboard_owner_screen.dart';
import 'sales_agent_placeholder_screen.dart';
import 'sales_agent_portfolio_screen.dart';
import 'sales_agent_redeem_subscription_screen.dart';
import 'sales_agent_update_profile_screen.dart';

class SalesAgentShellScreen extends StatefulWidget {
  const SalesAgentShellScreen({super.key});

  @override
  State<SalesAgentShellScreen> createState() => _SalesAgentShellScreenState();
}

class _SalesAgentShellScreenState extends State<SalesAgentShellScreen>
    with SingleTickerProviderStateMixin {
  late final SecureStorage _storage;
  late final ApiClient _apiClient;
  late final SalesAgentRepositoryImpl _repository;
  late final SalesAgentCubit _cubit;
  int _index = 0;

  late final AnimationController _animationController;
  late final Animation<double> _fadeScreen;
  late final Animation<double> _scaleFab;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorage();
    _apiClient = ApiClient(secureStorage: _storage);
    final remoteDataSource = SalesAgentRemoteDataSource(apiClient: _apiClient);
    _repository = SalesAgentRepositoryImpl(remoteDataSource: remoteDataSource);
    _cubit = SalesAgentCubit(repository: _repository);
    _cubit.initialize();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeScreen = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _scaleFab = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cubit.dispose();
    super.dispose();
  }

  Future<void> _redirectByRole(String role) async {
    if (!mounted) return;
    await Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) {
          if (role == 'admin') return const AdminDashboardScreen();
          if (role == 'owner') return const OwnerShellScreen();
          return const GuestShellScreen();
        },
      ),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    final authState = context.read<AuthState>();
    final cartState = context.read<CartState>();
    final storeCubit = context.read<StoreCubit>();

    try {
      await _cubit.logout();
    } catch (_) {}

    await _apiClient.resetSessionHeaders();
    await _storage.clearSession();
    cartState.clear();
    storeCubit.clearCurrentStore();
    await authState.setUnauthenticated();

    if (!mounted) return;
    await Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const GuestShellScreen()),
      (_) => false,
    );
  }

  Future<void> _openOnboarding() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<SalesAgentCubit>.value(
          value: _cubit,
          child: const SalesAgentOnboardOwnerScreen(),
        ),
      ),
    );
  }

  Future<void> _openActivationCode() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<SalesAgentCubit>.value(
          value: _cubit,
          child: const SalesAgentActivationCodeScreen(),
        ),
      ),
    );
  }

  Future<void> _openRedeem() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<SalesAgentCubit>.value(
          value: _cubit,
          child: const SalesAgentRedeemSubscriptionScreen(),
        ),
      ),
    );
  }

  Future<void> _openUpdateProfile() async {
    final authState = context.read<AuthState>();
    final initialEmail = (authState.email ?? _cubit.state.profile?.email ?? '').trim();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<SalesAgentUpdateProfileCubit>(
          create: (_) => SalesAgentUpdateProfileCubit(
            updateProfileUseCase: UpdateProfileUseCase(_repository),
            secureStorage: _storage,
            authState: authState,
            salesAgentCubit: _cubit,
          ),
          child: SalesAgentUpdateProfileScreen(initialEmail: initialEmail),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final role = (authState.role ?? '').trim().toLowerCase();

    if (!authState.isAuthenticated) {
      return const GuestShellScreen();
    }

    if (role != 'sales_agent') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _redirectByRole(role);
      });
      return const Scaffold(
        backgroundColor: Color(0xFF05050F),
        body: Center(
          child: _GlassLoader(),
        ),
      );
    }

    return ChangeNotifierProvider<SalesAgentCubit>.value(
      value: _cubit,
      child: Consumer<SalesAgentCubit>(
        builder: (context, cubit, _) {
          final state = cubit.state;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red.shade800,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
              cubit.clearMessages();
            }
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
              cubit.clearMessages();
            }
          });

          final tabs = <Widget>[
            SalesAgentDashboardScreen(
              onOpenOnboarding: _openOnboarding,
              onOpenActivationCode: _openActivationCode,
              onOpenRedeem: _openRedeem,
            ),
            const SalesAgentPortfolioScreen(),
            SalesAgentPlaceholderScreen(
              title: 'Subscriptions',
              description: 'Use quick actions for activation and redeem in this phase.',
              icon: Icons.subscriptions_rounded,
              action: Row(
                children: [
                  Expanded(child: _PremiumOutlineButton(onPressed: _openActivationCode, icon: Icons.key_rounded, label: 'Create Code')),
                  const SizedBox(width: 12),
                  Expanded(child: _PremiumOutlineButton(onPressed: _openRedeem, icon: Icons.redeem_rounded, label: 'Redeem')),
                ],
              ),
            ),
            SalesAgentPlaceholderScreen(
              title: 'Profile',
              description: '${state.profile?.name ?? 'Sales Agent'}\n${state.profile?.email ?? ''}',
              icon: Icons.person_rounded,
              action: Column(
                children: [
                  SizedBox(width: double.infinity, child: _PremiumOutlineButton(onPressed: _openUpdateProfile, icon: Icons.edit_rounded, label: 'Update Profile')),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: _PremiumGradientButton(onPressed: _logout, icon: Icons.logout_rounded, label: 'Logout')),
                ],
              ),
            ),
          ];

          return Scaffold(
            backgroundColor: const Color(0xFF05050F),
            body: FadeTransition(
              opacity: _fadeScreen,
              child: Column(
                children: [
                  _PremiumHeader(
                    title: 'Sales Agent',
                    onRefresh: cubit.refreshBusinessTypes,
                  ),
                  Expanded(
                    child: IndexedStack(index: _index, children: tabs),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: _PremiumBottomNavBar(
              selectedIndex: _index,
              onTap: (index) {
                setState(() => _index = index);
              },
            ),
          );
        },
      ),
    );
  }
}

// =============== فاخر وأنيق ===============
class _GlassLoader extends StatelessWidget {
  const _GlassLoader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
      ),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Color(0xFFB77CFF),
          ),
        ),
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({required this.title, required this.onRefresh});
  final String title;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 55, left: 20, right: 20, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A3A).withOpacity(0.85), const Color(0xFF0E0E1E).withOpacity(0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF7B61FF).withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: const Color(0xFF7B61FF).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Color(0xFFB77CFF), size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFFB77CFF)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumBottomNavBar extends StatelessWidget {
  const _PremiumBottomNavBar({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF12122A).withOpacity(0.95), const Color(0xFF1A1A35).withOpacity(0.95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFF7B61FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home', 0),
          _buildNavItem(Icons.storefront_outlined, Icons.storefront_rounded, 'Portfolio', 1),
          _buildNavItem(Icons.subscriptions_outlined, Icons.subscriptions_rounded, 'Subs', 2),
          _buildNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: isSelected ? const Color(0xFF7B61FF).withOpacity(0.2) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFFB77CFF) : Colors.white.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFFB77CFF) : Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumOutlineButton extends StatelessWidget {
  const _PremiumOutlineButton({required this.onPressed, required this.icon, required this.label});
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF7B61FF), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _PremiumGradientButton extends StatelessWidget {
  const _PremiumGradientButton({required this.onPressed, required this.icon, required this.label});
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFFB77CFF)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF7B61FF).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}