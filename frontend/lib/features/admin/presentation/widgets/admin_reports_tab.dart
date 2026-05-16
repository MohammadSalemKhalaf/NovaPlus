import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/admin_business_type_entity.dart';
import '../../domain/entities/admin_sales_agent_entity.dart';
import '../../domain/entities/admin_report_filters.dart';
import '../../domain/entities/admin_report_models.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({
    super.key,
    required this.repository,
    required this.refreshToken,
  });

  final AdminDashboardRepository repository;
  final int refreshToken;

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab>
    with SingleTickerProviderStateMixin {
  final TextEditingController _storesSearchController = TextEditingController();
  final TextEditingController _subscriptionsSearchController = TextEditingController();
  final TextEditingController _usersSearchController = TextEditingController();
  late TabController _tabController;
  Timer? _searchDebounce;

  StoresFilter _storesFilter = StoresFilter.initial;
  SubscriptionFilter _subscriptionFilter = SubscriptionFilter.initial;
  UsersFilter _usersFilter = UsersFilter.initial;

  final List<String> _userRoles = const <String>['all', 'owner', 'manager', 'staff'];

  bool _isLoading = true;
  String? _errorMessage;
  int _loadVersion = 0;

  List<_AgentOption> _agentOptions = const <_AgentOption>[];
  List<_CreatedOwnersAgentRow> _createdOwnersRows =
      const <_CreatedOwnersAgentRow>[];
  List<_RevenueAgentRow> _revenueRows = const <_RevenueAgentRow>[];
  List<_RevenueAgentRow> _topRevenueRows = const <_RevenueAgentRow>[];
  List<_SubscriptionRow> _activeSubscriptions = const <_SubscriptionRow>[];
  List<_SubscriptionRow> _expiredSubscriptions = const <_SubscriptionRow>[];
  List<_SubscriptionRow> _expiringSoonSubscriptions =
      const <_SubscriptionRow>[];
  List<StoreModel> _storesList = const <StoreModel>[];
  List<BusinessTypeModel> _businessTypes = const <BusinessTypeModel>[];

  // ── colour tokens ──────────────────────────────────────────────────────────
  static const Color _bg0 = Color(0xFF07071A);
  static const Color _bg1 = Color(0xFF0F0F28);
  static const Color _bg2 = Color(0xFF16163A);
  static const Color _bg3 = Color(0xFF1E1E48);
  static const Color _border = Color(0xFF2A2A58);
  static const Color _textPrimary = Color(0xFFF0F0FF);
  static const Color _textSecondary = Color(0xFF9090BC);
  static const Color _textMuted = Color(0xFF5A5A8A);
  static const Color _accent = Color(0xFF7B61FF);
  static const Color _accentBlue = Color(0xFF3A8DFF);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _silver = Color(0xFFC0C0C0);
  static const Color _bronze = Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurrentTabData();
  }

  @override
  void didUpdateWidget(covariant AdminReportsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadCurrentTabData();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _storesSearchController.dispose();
    _subscriptionsSearchController.dispose();
    _usersSearchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    _resetFiltersForTab(_tabController.index);
    _loadCurrentTabData();
  }

  void _runDebouncedLoad(VoidCallback action) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), action);
  }

  // ── data loading ───────────────────────────────────────────────────────────

  Future<void> _loadCurrentTabData() async {
    final tabIndex = _tabController.index;
    switch (tabIndex) {
      case 0:
        await _loadSubscriptionsTabData();
        break;
      case 1:
        await _loadStoresTabData();
        break;
      case 2:
        await _loadUsersTabData();
        break;
      case 3:
        await _loadRevenueTabData();
        break;
    }
  }

  void _resetFiltersForTab(int index) {
    setState(() {
      if (index == 0) {
        _subscriptionFilter = SubscriptionFilter.initial;
        _subscriptionsSearchController.clear();
      } else if (index == 1) {
        _storesFilter = StoresFilter.initial;
        _storesSearchController.clear();
      } else if (index == 2) {
        _usersFilter = UsersFilter.initial;
        _usersSearchController.clear();
      }
    });
  }

  Future<void> _ensureAgentOptions() async {
    if (_agentOptions.isNotEmpty) {
      return;
    }

    final agents = await widget.repository.getSalesAgents(perPage: 100);
    _agentOptions = _parseAgentDirectory(agents);
  }

  Future<void> _loadSubscriptionsTabData() async {
    final version = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _ensureAgentOptions();
      final subscriptions = await widget.repository.getSubscriptions(_subscriptionFilter);
      if (!mounted || version != _loadVersion) {
        return;
      }

      final filteredByStatus = subscriptions.where((item) {
        final selectedStatus = _subscriptionFilter.status?.trim().toLowerCase();
        if (selectedStatus == null || selectedStatus.isEmpty || selectedStatus == 'all') {
          return true;
        }
        final status = (item['status']?.toString() ?? '').toLowerCase();
        return status == selectedStatus;
      }).toList(growable: false);

      setState(() {
        _activeSubscriptions = _parseSubscriptionRows(
          <String, dynamic>{'subscriptions': filteredByStatus.where((item) => (item['status']?.toString().toLowerCase() ?? '').contains('active')).toList(growable: false)},
        );
        _expiredSubscriptions = _parseSubscriptionRows(
          <String, dynamic>{'subscriptions': filteredByStatus.where((item) => (item['status']?.toString().toLowerCase() ?? '').contains('expired')).toList(growable: false)},
        );
        _expiringSoonSubscriptions = _parseSubscriptionRows(
          <String, dynamic>{'subscriptions': filteredByStatus.where((item) => (item['status']?.toString().toLowerCase() ?? '').contains('expiring')).toList(growable: false)},
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStoresTabData() async {
    final version = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        widget.repository.getStores(_storesFilter),
        widget.repository.getBusinessTypes(),
      ]);
        final stores = results[0] as List<StoreModel>;
        final businessTypeEntities = results[1] as List<AdminBusinessTypeEntity>;
      final businessTypes = businessTypeEntities
          .map(BusinessTypeModel.fromEntity)
          .toList(growable: false);

      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() {
        _storesList = stores;
        _businessTypes = businessTypes;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsersTabData() async {
    final version = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _ensureAgentOptions();
      final reportRows = await widget.repository.getAgentReport(_usersFilter);
      if (!mounted || version != _loadVersion) {
        return;
      }

      final query = _usersFilter.search?.trim().toLowerCase() ?? '';
      final role = _usersFilter.role?.trim().toLowerCase() ?? 'all';
      final filtered = reportRows.where((agent) {
        if (query.isEmpty) {
          return true;
        }
        final matchesAgent = agent.name.toLowerCase().contains(query) || agent.email.toLowerCase().contains(query);
        final matchesOwner = agent.owners.any((owner) =>
            owner.name.toLowerCase().contains(query) || owner.email.toLowerCase().contains(query));
        return matchesAgent || matchesOwner;
      }).map((agent) {
        if (role == 'all' || role.isEmpty) {
          return agent;
        }
        final owners = agent.owners.where((owner) => owner.role.toLowerCase() == role).toList(growable: false);
        return SalesAgentModel(
          id: agent.id,
          name: agent.name,
          email: agent.email,
          status: agent.status,
          createdAt: agent.createdAt,
          ownersCount: owners.length,
          storesCount: owners.fold<int>(0, (sum, owner) => sum + owner.stores.length),
          owners: owners,
        );
      }).where((agent) => agent.owners.isNotEmpty || role == 'all' || role.isEmpty).toList(growable: false);

      setState(() {
        _createdOwnersRows = filtered
            .map(
              (item) => _CreatedOwnersAgentRow(
                id: item.id,
                name: item.name,
                email: item.email,
                status: item.status,
                createdAt: item.createdAt,
                ownersCount: item.ownersCount,
                storesCount: item.storesCount,
                owners: item.owners
                    .map(
                      (owner) => _OwnerSummary(
                        id: owner.id,
                        name: owner.name,
                        email: owner.email,
                        status: owner.status,
                        createdAt: owner.createdAt,
                        stores: owner.stores
                            .map(
                              (store) => _StoreSummary(
                                id: store.id,
                                name: store.name,
                                slug: store.slug,
                                status: store.status,
                                businessTypeId: 0,
                                createdAt: store.createdAt,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRevenueTabData() async {
    final version = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<Map<String, dynamic>>([
        widget.repository.getRevenueByAgentReport(),
        widget.repository.getTopRevenueAgents(limit: 8),
      ]);
      if (!mounted || version != _loadVersion) {
        return;
      }

      setState(() {
        _revenueRows = _parseRevenueRows(results[0]);
        _topRevenueRows = _parseRevenueRows(results[1]);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  // ── parsers ────────────────────────────────────────────────────────────────

  List<_AgentOption> _parseAgentDirectory(List<AdminSalesAgentEntity> agents) {
    return agents
        .map((a) => _AgentOption(id: a.id, name: a.name, email: a.email))
        .toList(growable: false)
      ..sort((l, r) => l.name.compareTo(r.name));
  }

  List<_CreatedOwnersAgentRow> _parseCreatedOwnersRows(dynamic data) {
    return _readList(data, 'sales_agents')
        .map((item) => _CreatedOwnersAgentRow(
              id: _readInt(item, 'id') ?? 0,
              name: _readString(item, 'name'),
              email: _readString(item, 'email'),
              status: _readString(item, 'status'),
              createdAt: _readString(item, 'created_at'),
              ownersCount: _readInt(item, 'owners_count') ?? 0,
              storesCount: _readInt(item, 'stores_count') ?? 0,
              owners: _readOwners(item['owners']),
            ))
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  List<_OwnerSummary> _readOwners(dynamic data) {
    return _readListValue(data)
        .map((item) => _OwnerSummary(
              id: _readInt(item, 'id') ?? 0,
              name: _readString(item, 'name'),
              email: _readString(item, 'email'),
              status: _readString(item, 'status'),
              createdAt: _readString(item, 'created_at'),
              stores: _readStores(item['stores']),
            ))
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  List<_StoreSummary> _readStores(dynamic data) {
    return _readListValue(data)
        .map((item) => _StoreSummary(
              id: _readInt(item, 'id') ?? 0,
              name: _readString(item, 'name'),
              slug: _readString(item, 'slug'),
              status: _readString(item, 'status'),
              businessTypeId: _readInt(item, 'business_type_id') ?? 0,
              createdAt: _readString(item, 'created_at'),
            ))
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  List<_RevenueAgentRow> _parseRevenueRows(dynamic data) {
    return _readList(data, 'agents')
        .map((item) => _RevenueAgentRow(
              id: _readInt(item, 'user_id') ?? _readInt(item, 'id') ?? 0,
              name: _readString(item, 'name'),
              email: _readString(item, 'email'),
              totalSubscriptions: _readInt(item, 'total_subscriptions') ?? 0,
              totalRevenue: _readDouble(item, 'total_revenue') ?? 0,
              performanceScore: _readDouble(item, 'performance_score'),
            ))
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  List<_SubscriptionRow> _parseSubscriptionRows(dynamic data) {
    return _readList(data, 'subscriptions')
        .map((item) => _SubscriptionRow(
              id: _readInt(item, 'id') ?? 0,
              tenantName: _readNestedString(item, 'tenant', 'name'),
              tenantSlug: _readNestedString(item, 'tenant', 'slug'),
              planCode: _readString(item, 'plan_code'),
              code: _readString(item, 'code'),
              activationCode: _readString(item, 'activation_code'),
              status: _readString(item, 'status'),
              startsAt: _readString(item, 'starts_at'),
              endsAt: _readString(item, 'ends_at'),
              createdAt: _readString(item, 'created_at'),
              createdByName:
                  _readNestedString(item, 'created_by_admin', 'name'),
              soldByName: _readNestedString(item, 'sold_by_user', 'name'),
            ))
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _readList(dynamic data, String key) {
    if (data is Map) return _readListValue(data[key]);
    return const [];
  }

  List<Map<String, dynamic>> _readListValue(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  int? _readInt(Map<String, dynamic> item, String key) {
    final v = item[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  double? _readDouble(Map<String, dynamic> item, String key) {
    final v = item[key];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  String _readString(Map<String, dynamic> item, String key) =>
      item[key]?.toString().trim() ?? '';

  String _readNestedString(
      Map<String, dynamic> item, String parentKey, String childKey) {
    final nested = item[parentKey];
    if (nested is Map) return nested[childKey]?.toString().trim() ?? '';
    return '';
  }

  // ── computed ───────────────────────────────────────────────────────────────

  List<_AgentOption> _filteredAgentOptions(String query, int? selectedAgentId) {
    final normalized = query.trim().toLowerCase();
    final filtered = _agentOptions.where((item) {
      if (normalized.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(normalized) ||
          item.email.toLowerCase().contains(normalized);
    }).toList(growable: false);

    if (selectedAgentId != null) {
      final selected = _agentOptions.where((item) => item.id == selectedAgentId).toList(growable: false);
      for (final option in selected) {
        if (filtered.every((item) => item.id != option.id)) {
          filtered.insert(0, option);
        }
      }
    }
    return filtered;
  }

  _AgentOption? _selectedAgentOption(int? selectedAgentId) {
    if (selectedAgentId == null) {
      return null;
    }
    for (final option in _agentOptions) {
      if (option.id == selectedAgentId) {
        return option;
      }
    }
    return null;
  }

  int get _createdOwnerCount =>
      _createdOwnersRows.fold(0, (s, i) => s + i.ownersCount);
  int get _storeCount =>
      _createdOwnersRows.fold(0, (s, i) => s + i.storesCount);
  double get _revenueTotal =>
      _revenueRows.fold(0, (s, i) => s + i.totalRevenue);

  // ── formatting helpers ─────────────────────────────────────────────────────

  String _formatMoney(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}K';
    return '\$${value.toStringAsFixed(0)}';
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String value) {
    final n = value.toLowerCase().trim();
    if (n.contains('active')) return _green;
    if (n.contains('expired')) return _red;
    if (n.contains('cancel')) return _amber;
    return _accent;
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();

    return Container(
      color: _bg0,
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          // ── subtle separator line ──────────────────────────────────────────
          Container(height: 1, color: _border.withOpacity(0.5)),
          // ── extra breathing room below the tab bar ─────────────────────────
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubscriptionsTabContent(),
                _buildStoresTabContent(),
                _buildUsersTabContent(),
                _buildRevenueTabContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg2, _bg1],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _accent.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row
          Row(
            children: [
              _iconBox(Icons.assessment_rounded,
                  [_accent, _accentBlue], 18),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reports & Analytics',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              _refreshButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _refreshButton() {
    return GestureDetector(
      onTap: _loadCurrentTabData,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_accent, _accentBlue]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 17),
      ),
    );
  }

  // ── tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withOpacity(0.6), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_accent, _accentBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: _textSecondary,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        padding: EdgeInsets.zero,
        labelPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        tabs: const [
          Tab(text: 'Subscriptions', height: 38),
          Tab(text: 'Stores', height: 38),
          Tab(text: 'Users', height: 38),
          Tab(text: 'Revenue', height: 38),
        ],
      ),
    );
  }

  // ── loading / error ────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Container(
      color: _bg0,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          builder: (context, v, child) => Transform.scale(
            scale: v,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_accent, _accentBlue]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ],
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: _bg0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_red, Color(0xFFD32F2F)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(height: 16),
              const Text('Failed to load reports',
                  style: TextStyle(
                      color: _textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                style:
                    const TextStyle(color: _textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _loadCurrentTabData,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_accent, _accentBlue]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: _accent.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 17),
                      SizedBox(width: 8),
                      Text('Retry',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SUBSCRIPTIONS TAB ──────────────────────────────────────────────────────

  Widget _buildSubscriptionsFilters() {
    final selectedAgent = _selectedAgentOption(_subscriptionFilter.agentId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.7), width: 1),
      ),
      child: Column(
        children: [
          TextField(
            controller: _subscriptionsSearchController,
            onChanged: (value) {
              _subscriptionFilter = _subscriptionFilter.copyWith(storeName: value, page: 1);
              _runDebouncedLoad(_loadSubscriptionsTabData);
            },
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Store name',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.storefront_rounded, color: _accent, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: _bg0,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final agentField = DropdownButtonFormField<int?>(
                value: _subscriptionFilter.agentId,
                isExpanded: true,
                dropdownColor: _bg2,
                decoration: _filterDropdownDecoration('Agent', Icons.people_rounded),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All Agents')),
                  ..._filteredAgentOptions('', _subscriptionFilter.agentId)
                      .map((option) => DropdownMenuItem<int?>(
                            value: option.id,
                            child: Text(option.name, overflow: TextOverflow.ellipsis),
                          )),
                ],
                onChanged: (value) {
                  setState(() {
                    _subscriptionFilter = _subscriptionFilter.copyWith(agentId: value, page: 1);
                  });
                  _loadSubscriptionsTabData();
                },
              );

              final statusField = DropdownButtonFormField<String>(
                value: _subscriptionFilter.status ?? 'all',
                isExpanded: true,
                dropdownColor: _bg2,
                decoration: _filterDropdownDecoration('Status', Icons.verified_rounded),
                items: const [
                  DropdownMenuItem<String>(value: 'all', child: Text('All')),
                  DropdownMenuItem<String>(value: 'active', child: Text('Active')),
                  DropdownMenuItem<String>(value: 'expired', child: Text('Expired')),
                  DropdownMenuItem<String>(value: 'expiring', child: Text('Expiring')),
                ],
                onChanged: (value) {
                  setState(() {
                    _subscriptionFilter = _subscriptionFilter.copyWith(status: value, page: 1);
                  });
                  _loadSubscriptionsTabData();
                },
              );

              if (compact) {
                return Column(
                  children: [
                    agentField,
                    const SizedBox(height: 10),
                    statusField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: agentField),
                  const SizedBox(width: 10),
                  Expanded(child: statusField),
                ],
              );
            },
          ),
          if (selectedAgent != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Agent: ${selectedAgent.name}',
                style: const TextStyle(color: _textMuted, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTabContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      children: [
        _buildSubscriptionsFilters(),
        _subscriptionSection(
          title: 'Active Subscriptions',
          subtitle: 'Live subscriptions in service',
          rows: _activeSubscriptions,
          accent: _green,
          emptyMessage: 'No active subscriptions',
        ),
        const SizedBox(height: 14),
        _subscriptionSection(
          title: 'Expired Subscriptions',
          subtitle: 'Subscriptions that have ended',
          rows: _expiredSubscriptions,
          accent: _red,
          emptyMessage: 'No expired subscriptions',
        ),
        const SizedBox(height: 14),
        _subscriptionSection(
          title: 'Expiring Soon',
          subtitle: 'Subscriptions near expiration',
          rows: _expiringSoonSubscriptions,
          accent: _amber,
          emptyMessage: 'No subscriptions expiring soon',
        ),
      ],
    );
  }

  Widget _subscriptionSection({
    required String title,
    required String subtitle,
    required List<_SubscriptionRow> rows,
    required Color accent,
    required String emptyMessage,
  }) {
    return _sectionContainer(
      accent: accent,
      header: _sectionHeader(
        icon: Icons.subscriptions_rounded,
        title: title,
        subtitle: subtitle,
        count: rows.length,
        accent: accent,
      ),
      child: rows.isEmpty
          ? _emptyMessage(emptyMessage)
          : Column(
              children: rows
                  .map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _subscriptionCard(row, accent),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _subscriptionCard(_SubscriptionRow row, Color accent) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _bg0,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _miniIconBox(Icons.store_rounded, accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.tenantName,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(row.tenantSlug,
                        style: const TextStyle(
                            color: _textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _statusBadge(row.status, _statusColor(row.status)),
            ],
          ),
          Divider(height: 16, color: _border.withOpacity(0.5)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.code_rounded, 'Code',
                  row.code.isEmpty ? '—' : row.code),
              _chip(Icons.subscriptions_rounded, 'Plan',
                  row.planCode.isEmpty ? '—' : row.planCode),
              _chip(
                  Icons.person_rounded,
                  'By',
                  row.createdByName.isEmpty
                      ? (row.soldByName.isEmpty ? '—' : row.soldByName)
                      : row.createdByName),
              _chip(Icons.event_rounded, 'Ends',
                  _formatDate(row.endsAt)),
            ],
          ),
        ],
      ),
    );
  }

  // ── STORES TAB ─────────────────────────────────────────────────────────────

  Widget _buildStoresFilters() {
    final businessTypeItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('All Types')),
      ..._businessTypes.map(
        (item) => DropdownMenuItem<int?>(
          value: item.id,
          child: Text(item.name.isEmpty ? 'Type #${item.id}' : item.name),
        ),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.7), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          final searchField = TextField(
            controller: _storesSearchController,
            onChanged: (value) {
              _storesFilter = _storesFilter.copyWith(search: value, page: 1);
              _runDebouncedLoad(_loadStoresTabData);
            },
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search stores',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: _accentBlue, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: _bg0,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          );

          final businessTypeField = DropdownButtonFormField<int?>(
            value: _storesFilter.businessTypeId,
            isExpanded: true,
            dropdownColor: _bg2,
            decoration: _filterDropdownDecoration('Business Type', Icons.category_rounded),
            items: businessTypeItems,
            onChanged: (value) {
              print('Selected business type id: $value');
              setState(() {
                _storesFilter = _storesFilter.copyWith(businessTypeId: value, page: 1);
              });
              _loadStoresTabData();
            },
          );

          if (compact) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                businessTypeField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 10),
              Expanded(child: businessTypeField),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStoresTabContent() {
    if (_storesList.isEmpty) {
      return _emptyState('No Stores Found',
          'No stores are available in the system');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      children: [
        _buildStoresFilters(),
        _sectionContainer(
          accent: _accentBlue,
          header: _sectionHeader(
            icon: Icons.store_rounded,
            title: 'All Stores',
            subtitle: 'Complete list of stores in the system',
            count: _storesList.length,
            accent: _accentBlue,
          ),
          child: _storesList.isEmpty
              ? _emptyMessage('No stores match this filter')
              : Column(
            children: _storesList.map((store) {
              final name = store.name.isEmpty ? '—' : store.name;
              final slug = store.slug.isEmpty ? '—' : store.slug;
              final businessType = _businessTypeNameById(store.businessTypeId);
              final status = store.status.isEmpty ? '—' : store.status;
              final createdAt = store.createdAt;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _storeCard(
                    name: name,
                    slug: slug,
                    businessType: businessType,
                    status: status,
                    createdAt: createdAt),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _storeCard({
    required String name,
    required String slug,
    required String businessType,
    required String status,
    required String createdAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _bg0,
        borderRadius: BorderRadius.circular(15),
        border:
            Border.all(color: _accentBlue.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _miniIconBox(Icons.storefront_rounded, _accentBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(slug,
                        style: const TextStyle(
                            color: _textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _statusBadge(status, _statusColor(status)),
            ],
          ),
          Divider(height: 16, color: _border.withOpacity(0.5)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.category_rounded, 'Type', businessType,
                  color: _accentBlue),
              _chip(Icons.event_rounded, 'Created',
                  _formatDate(createdAt),
                  color: _accentBlue),
            ],
          ),
        ],
      ),
    );
  }

  String _businessTypeNameById(int id) {
    if (id <= 0 || _businessTypes.isEmpty) {
      return '—';
    }
    for (final item in _businessTypes) {
      if (item.id == id) {
        final name = item.name.trim();
        return name.isEmpty ? '—' : name;
      }
    }
    return '—';
  }

  // ── USERS TAB ──────────────────────────────────────────────────────────────

  Widget _buildUsersFilters() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withOpacity(0.7), width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          final searchField = TextField(
            controller: _usersSearchController,
            onChanged: (value) {
              _usersFilter = _usersFilter.copyWith(search: value);
              _runDebouncedLoad(_loadUsersTabData);
            },
            style: const TextStyle(color: _textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search user / owner',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, color: _accent, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: _bg0,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          );

          final roleField = DropdownButtonFormField<String>(
            value: _usersFilter.role ?? 'all',
            isExpanded: true,
            dropdownColor: _bg2,
            decoration: _filterDropdownDecoration('Role', Icons.badge_rounded),
            items: _userRoles
                .map((value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value == 'all' ? 'All Roles' : value),
                    ))
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _usersFilter = _usersFilter.copyWith(role: value);
              });
              _loadUsersTabData();
            },
          );

          if (compact) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                roleField,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 10),
              Expanded(child: roleField),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsersTabContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      children: [
        _buildUsersFilters(),
        _sectionContainer(
          accent: _accent,
          header: _sectionHeader(
            icon: Icons.people_rounded,
            title: 'Created Owners',
            subtitle: 'Owners created by each sales agent',
            count: _createdOwnersRows.length,
            accent: _accent,
          ),
          child: _createdOwnersRows.isEmpty
              ? _emptyMessage('No owners found')
              : Column(
                  children: _createdOwnersRows
                      .map((row) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _agentCard(row),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _agentCard(_CreatedOwnersAgentRow row) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _bg0,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _accent.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _miniIconBox(Icons.person_rounded, _accent,
                  gradient: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(row.email,
                        style: const TextStyle(
                            color: _textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _statusBadge(row.status, _statusColor(row.status)),
            ],
          ),
          Divider(height: 16, color: _border.withOpacity(0.5)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.people_rounded, 'Owners', '${row.ownersCount}'),
              _chip(Icons.store_rounded, 'Stores', '${row.storesCount}'),
              _chip(Icons.event_rounded, 'Joined',
                  _formatDate(row.createdAt)),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showCreatedOwnersDetails(row),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_accent, _accentBlue]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_rounded,
                      size: 15, color: Colors.white),
                  SizedBox(width: 7),
                  Text('View Details',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── REVENUE TAB ────────────────────────────────────────────────────────────

  Widget _buildRevenueTabContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
      children: [
        _sectionContainer(
          accent: _green,
          header: _sectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Revenue by Agent',
            subtitle: 'Aggregated subscription revenue per agent',
            count: _revenueRows.length,
            accent: _green,
          ),
          child: _revenueRows.isEmpty
              ? _emptyMessage('No revenue data found')
              : Column(
                  children: _revenueRows
                      .map((row) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _revenueCard(row),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        _sectionContainer(
          accent: _amber,
          header: _sectionHeader(
            icon: Icons.leaderboard_rounded,
            title: 'Top Revenue Agents',
            subtitle: 'Highest revenue ranking',
            count: _topRevenueRows.length,
            accent: _amber,
          ),
          child: _topRevenueRows.isEmpty
              ? _emptyMessage('No top revenue data found')
              : Column(
                  children: _topRevenueRows
                      .asMap()
                      .entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _topRevenueCard(e.value, e.key + 1),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _revenueCard(_RevenueAgentRow row) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _bg0,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _green.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _miniIconBox(Icons.attach_money_rounded, _green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(row.email,
                        style: const TextStyle(
                            color: _textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 16, color: _border.withOpacity(0.5)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.subscriptions_rounded, 'Subs',
                  '${row.totalSubscriptions}'),
              _chip(Icons.attach_money_rounded, 'Revenue',
                  _formatMoney(row.totalRevenue),
                  color: _green),
              if (row.performanceScore != null)
                _chip(Icons.star_rounded, 'Score',
                    row.performanceScore!.toStringAsFixed(1),
                    color: _amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topRevenueCard(_RevenueAgentRow row, int rank) {
    final rankColor = rank == 1
        ? _gold
        : rank == 2
            ? _silver
            : rank == 3
                ? _bronze
                : _textSecondary;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _bg0,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _amber.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [rankColor, rankColor.withOpacity(0.6)]),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                        color: rankColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                child: Center(
                  child: Text('#$rank',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name,
                        style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(row.email,
                        style: const TextStyle(
                            color: _textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 16, color: _border.withOpacity(0.5)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.attach_money_rounded, 'Revenue',
                  _formatMoney(row.totalRevenue),
                  color: _green),
              if (row.performanceScore != null)
                _chip(Icons.star_rounded, 'Score',
                    row.performanceScore!.toStringAsFixed(1),
                    color: _amber),
            ],
          ),
        ],
      ),
    );
  }

  // ── SHARED WIDGETS ─────────────────────────────────────────────────────────

  Widget _sectionContainer({
    required Color accent,
    required Widget header,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg2, _bg1],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
              color: accent.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _filterDropdownDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textMuted, fontSize: 12),
      prefixIcon: Icon(icon, color: _accent, size: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: _bg0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required Color accent,
  }) {
    return Row(
      children: [
        _iconBox(icon, [accent, accent.withOpacity(0.7)], 17),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              Text(subtitle,
                  style: const TextStyle(
                      color: _textSecondary, fontSize: 11)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: accent.withOpacity(0.3), width: 1),
          ),
          child: Text('$count',
              style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
      ],
    );
  }

  Widget _iconBox(IconData icon, List<Color> colors, double size) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: colors.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size),
    );
  }

  Widget _miniIconBox(IconData icon, Color color,
      {bool gradient = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: gradient
            ? LinearGradient(
                colors: [color, color.withOpacity(0.7)])
            : null,
        color: gradient ? null : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon,
          size: 15, color: gradient ? Colors.white : color),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10)),
    );
  }

  Widget _chip(IconData icon, String label, String value,
      {Color color = _accent}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: color.withOpacity(0.18), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text('$label: ',
              style: const TextStyle(
                  color: _textMuted, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11)),
        ],
      ),
    );
  }

  Widget _emptyMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.inbox_rounded, size: 44, color: _accent),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBox(Icons.store_mall_directory_outlined,
                [_accent, _accentBlue], 30),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM SHEET ───────────────────────────────────────────────────────────

  void _showCreatedOwnersDetails(_CreatedOwnersAgentRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bg2, _bg0],
                ),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      children: [
                        // agent header
                        Row(
                          children: [
                            _iconBox(Icons.person_rounded,
                                [_accent, _accentBlue], 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(row.name,
                                      style: const TextStyle(
                                          color: _textPrimary,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 3),
                                  Text(row.email,
                                      style: const TextStyle(
                                          color: _textSecondary,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _bg3,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: _textPrimary, size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // stat chips
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _detailStat('Owners', '${row.ownersCount}',
                                Icons.people_rounded, _accent),
                            _detailStat('Stores', '${row.storesCount}',
                                Icons.store_rounded, _accentBlue),
                            _detailStat('Status', row.status,
                                Icons.verified_rounded,
                                _statusColor(row.status)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const Text('Owners & Stores',
                            style: TextStyle(
                                color: _textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        ...row.owners
                            .map((owner) => _ownerTile(owner)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailStat(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg0,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label,
              style:
                  const TextStyle(color: _textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _ownerTile(_OwnerSummary owner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: _accent,
        collapsedIconColor: _textSecondary,
        title: Text(owner.name,
            style: const TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        subtitle: Text(owner.email,
            style:
                const TextStyle(color: _textMuted, fontSize: 11)),
        trailing: _statusBadge(
            owner.status, _statusColor(owner.status)),
        children: [
          Divider(color: _border.withOpacity(0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniChip('Joined: ${_formatDate(owner.createdAt)}'),
              _miniChip('Stores: ${owner.stores.length}'),
            ],
          ),
          const SizedBox(height: 12),
          if (owner.stores.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No stores by this owner',
                  style: TextStyle(color: _textMuted, fontSize: 12)),
            )
          else
            ...owner.stores.map((store) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _bg0,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          color: _accent, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(store.name,
                                style: const TextStyle(
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                                '${store.slug} • ${store.status}',
                                style: const TextStyle(
                                    color: _textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      _statusBadge(
                          store.status, _statusColor(store.status)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: Text(label,
          style: const TextStyle(color: _textSecondary, fontSize: 11)),
    );
  }
}

// ── DATA CLASSES ───────────────────────────────────────────────────────────────

class _AgentOption {
  const _AgentOption({
    required this.id,
    required this.name,
    required this.email,
  });
  final int id;
  final String name;
  final String email;
}

class _CreatedOwnersAgentRow {
  const _CreatedOwnersAgentRow({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.ownersCount,
    required this.storesCount,
    required this.owners,
  });
  final int id;
  final String name;
  final String email;
  final String status;
  final String createdAt;
  final int ownersCount;
  final int storesCount;
  final List<_OwnerSummary> owners;
}

class _OwnerSummary {
  const _OwnerSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    required this.createdAt,
    required this.stores,
  });
  final int id;
  final String name;
  final String email;
  final String status;
  final String createdAt;
  final List<_StoreSummary> stores;
}

class _StoreSummary {
  const _StoreSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.businessTypeId,
    required this.createdAt,
  });
  final int id;
  final String name;
  final String slug;
  final String status;
  final int businessTypeId;
  final String createdAt;
}

class _RevenueAgentRow {
  const _RevenueAgentRow({
    required this.id,
    required this.name,
    required this.email,
    required this.totalSubscriptions,
    required this.totalRevenue,
    required this.performanceScore,
  });
  final int id;
  final String name;
  final String email;
  final int totalSubscriptions;
  final double totalRevenue;
  final double? performanceScore;
}

class _SubscriptionRow {
  const _SubscriptionRow({
    required this.id,
    required this.tenantName,
    required this.tenantSlug,
    required this.planCode,
    required this.code,
    required this.activationCode,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.createdAt,
    required this.createdByName,
    required this.soldByName,
  });
  final int id;
  final String tenantName;
  final String tenantSlug;
  final String planCode;
  final String code;
  final String activationCode;
  final String status;
  final String startsAt;
  final String endsAt;
  final String createdAt;
  final String createdByName;
  final String soldByName;
}