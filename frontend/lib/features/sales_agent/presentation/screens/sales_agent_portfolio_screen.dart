import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/sales_agent_remote_data_source.dart';
import '../../data/repositories/sales_agent_repository_impl.dart';
import '../../domain/usecases/get_portfolio_usecase.dart';
import '../cubit_or_bloc/sales_agent_cubit.dart';
import '../cubit_or_bloc/sales_agent_portfolio_cubit.dart';
import 'sales_agent_redeem_subscription_screen.dart';

class SalesAgentPortfolioScreen extends StatefulWidget {
  const SalesAgentPortfolioScreen({
    super.key,
    this.onActivate,
  });

  final Function(int tenantId, int ownerId)? onActivate;

  @override
  State<SalesAgentPortfolioScreen> createState() =>
      _SalesAgentPortfolioScreenState();
}

class _SalesAgentPortfolioScreenState extends State<SalesAgentPortfolioScreen>
    with SingleTickerProviderStateMixin {
  late final SalesAgentPortfolioCubit _cubit;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final remoteDataSource = SalesAgentRemoteDataSource(apiClient: apiClient);
    final repository = SalesAgentRepositoryImpl(remoteDataSource: remoteDataSource);
    final useCase = GetPortfolioUseCase(repository);

    _cubit = SalesAgentPortfolioCubit(getPortfolioUseCase: useCase);
    _cubit.initialize();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cubit.dispose();
    super.dispose();
  }

  Future<void> _openRedeemScreen(int tenantId, int ownerId) async {
    if (widget.onActivate != null) {
      widget.onActivate!(tenantId, ownerId);
      return;
    }

    await SecureStorage().saveTenantId(tenantId.toString());

    final redeemed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ChangeNotifierProvider<SalesAgentCubit>.value(
          value: context.read<SalesAgentCubit>(),
          child: SalesAgentRedeemSubscriptionScreen(initialTenantId: tenantId),
        ),
      ),
    );

    if (redeemed == true) {
      await _cubit.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SalesAgentPortfolioCubit>.value(
      value: _cubit,
      child: Consumer<SalesAgentPortfolioCubit>(
        builder: (context, cubit, _) {
          final state = cubit.state;
          
          // Debug logs
          print('PORTFOLIO SCREEN: Loading=${state.loading}, Items=${state.items.length}, Error=${state.errorMessage}');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            }
          });

          return FadeTransition(
            opacity: _fadeAnimation,
            child: Scaffold(
              backgroundColor: const Color(0xFF05050F),
              body: RefreshIndicator(
                onRefresh: cubit.refresh,
                backgroundColor: const Color(0xFF1A1A3A),
                color: const Color(0xFFB77CFF),
                child: _buildContent(state),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(SalesAgentPortfolioState state) {
    if (state.loading && state.items.isEmpty) {
      return _buildLoadingState();
    }

    if (state.items.isEmpty) {
      return _buildEmptyState();
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: _buildStats(state),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == state.items.length) {
                return const SizedBox(height: 32);
              }
              return _buildPortfolioCard(state.items[index]);
            },
            childCount: state.items.length + 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStats(SalesAgentPortfolioState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A3A).withOpacity(0.85),
            const Color(0xFF0E0E1E).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF7B61FF).withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B61FF).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Active', state.activeCount, Colors.green),
          _buildStatItem('Pending', state.pendingCount, Colors.orange),
          _buildStatItem('Expired', state.expiredCount, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioCard(dynamic item) {
    final store = item.store;
    final owner = item.owner;
    final status = item.status;
    final expiresAt = item.expiresAt;

    final statusColor = _getStatusColor(status);
    final statusLabel = status.toUpperCase();
    final isPending = status == 'pending';

    final dateText = expiresAt != null
        ? '${expiresAt.year}-${expiresAt.month.toString().padLeft(2, '0')}-${expiresAt.day.toString().padLeft(2, '0')}'
        : 'No expiry';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.95 + (value * 0.05),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A1A3A).withOpacity(0.9),
                const Color(0xFF0E0E1E).withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Name Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Owner: ${owner.name}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(
                  color: Colors.white.withOpacity(0.1),
                  height: 1,
                ),
                const SizedBox(height: 12),

                // Expiry Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Expires:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                // Action Button for Pending
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openRedeemScreen(
                        store.tenantId,
                        owner.id,
                      ),
                      icon: const Icon(Icons.redeem_rounded, size: 18),
                      label: const Text('Activate Subscription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
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
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your portfolio...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7B61FF).withOpacity(0.1),
                  const Color(0xFFB77CFF).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFF7B61FF).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 40,
              color: Color(0xFFB77CFF),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No clients yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Start by creating owner onboarding and their stores will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
