import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/state/store_cubit.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../guest/presentation/screens/guest_shell_screen.dart';
import '../../data/datasources/admin_dashboard_remote_data_source.dart';
import '../../data/repositories/admin_dashboard_repository_impl.dart';
import '../../domain/entities/admin_dashboard_data_entity.dart';
import '../../domain/entities/admin_business_type_entity.dart';
import '../../domain/entities/admin_sales_agent_entity.dart';
import '../../domain/entities/admin_sales_agent_overview_entity.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';
import '../widgets/admin_owner_onboarding_tab.dart';
import '../widgets/admin_overview_tab.dart';
import '../widgets/admin_reports_tab.dart';
import '../widgets/admin_sales_agents_tab.dart';

enum _AdminHomeTab { dashboard, salesAgents, ownerOnboarding, reports }

// ── colour palette ─────────────────────────────────────────────────────────────
class _C {
  static const bg0 = Color(0xFF05050F);
  static const bg1 = Color(0xFF0A0A1E);
  static const bg2 = Color(0xFF10102A);
  static const bg3 = Color(0xFF18183A);
  static const bg4 = Color(0xFF20204A);
  static const border = Color(0xFF252548);
  static const borderBright = Color(0xFF343464);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF9090BC);
  static const textMuted = Color(0xFF555580);
  static const accent = Color(0xFF7B61FF);
  static const accentBlue = Color(0xFF3A8DFF);
  static const accentCyan = Color(0xFF00D4FF);
  static const green = Color(0xFF22C55E);
  static const greenDark = Color(0xFF166534);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const gold = Color(0xFFFFD700);
  static const silver = Color(0xFFC0C0C0);
  static const bronze = Color(0xFFCD7F32);
  static const chartPurple = Color(0xFF8B5CF6);
  static const chartBlue = Color(0xFF3B82F6);
  static const chartTeal = Color(0xFF14B8A6);
  static const chartOrange = Color(0xFFF97316);
  static const chartPink = Color(0xFFEC4899);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final SecureStorage _storage;
  late final ApiClient _apiClient;
  late final AdminDashboardRepository _repository;
  late Future<AdminDashboardDataEntity> _dashboardFuture;
  late Future<List<AdminBusinessTypeEntity>> _businessTypesFuture;
  late Future<List<AdminSalesAgentEntity>> _salesAgentsFuture;
  late Future<List<AdminSalesAgentOverviewEntity>> _salesAgentsOverviewFuture;
  Future<
    ({
      List<AdminSalesAgentEntity> agents,
      Map<int, AdminSalesAgentOverviewEntity> overviewById,
    })
  >? _salesAgentsTabDataFuture;

  _AdminHomeTab _tab = _AdminHomeTab.dashboard;
  int _reportsRefreshToken = 0;
  String _salesAgentStatusFilter = '';

  final _onboardFormKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _tenantNameController = TextEditingController();
  final _tenantSlugController = TextEditingController();
  bool _isSlugManuallyEdited = false;
  String _businessMode = 'product';
  String _activationChannel = 'email';
  int? _selectedBusinessTypeId;
  bool _isSubmittingOnboard = false;
  String? _ownerEmailServerError;
  int? _lastOnboardedTenantId;
  int? _currentAdminUserId;

  bool _isSubmittingCode = false;
  String? _lastCreatedCode;

  String _range = 'Week';
  final _salesAgentCreateFormKey = GlobalKey<FormState>();
  final _salesAgentNameController = TextEditingController();
  final _salesAgentEmailController = TextEditingController();
  final _salesAgentPasswordController = TextEditingController();
  final _salesAgentSearchController = TextEditingController();
  bool _isSubmittingSalesAgentCreate = false;
  String? _salesAgentCreateEmailServerError;

  final _activationCodeFormKey = GlobalKey<FormState>();
  final _activationCodeController = TextEditingController();
  final _activationDurationController = TextEditingController(text: '12');
  final _activationNoteController = TextEditingController();
  String? _activationCodeSubmitError;
  final _redeemFormKey = GlobalKey<FormState>();
  final _redeemCodeController = TextEditingController();
  final _redeemTenantIdController = TextEditingController();
  bool _isSubmittingRedeem = false;
  String? _redeemSubmitError;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorage();
    _apiClient = ApiClient(secureStorage: _storage);
    final remoteDataSource =
        AdminDashboardRemoteDataSource(apiClient: _apiClient);
    _repository =
        AdminDashboardRepositoryImpl(remoteDataSource: remoteDataSource);
    _dashboardFuture = _repository.getDashboardData();
    _businessTypesFuture = _repository.getBusinessTypes();
    _salesAgentsFuture = _repository.getSalesAgents(perPage: 100);
    _salesAgentsOverviewFuture = _repository.getSalesAgentsOverview();
    _salesAgentsTabDataFuture = _loadSalesAgentsTabData();
    _tenantNameController.addListener(_handleTenantNameChanged);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _tenantNameController.dispose();
    _tenantSlugController.dispose();
    _salesAgentNameController.dispose();
    _salesAgentEmailController.dispose();
    _salesAgentPasswordController.dispose();
    _salesAgentSearchController.dispose();
    _activationCodeController.dispose();
    _activationDurationController.dispose();
    _activationNoteController.dispose();
    _redeemCodeController.dispose();
    _redeemTenantIdController.dispose();
    super.dispose();
  }

  String generateSlug(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
  }

  void _handleTenantNameChanged() {
    if (_isSlugManuallyEdited) return;
    final generated = generateSlug(_tenantNameController.text);
    if (_tenantSlugController.text == generated) return;
    _tenantSlugController.value = TextEditingValue(
      text: generated,
      selection: TextSelection.collapsed(offset: generated.length),
    );
  }

  Future<void> _reloadBusinessTypes() async {
    setState(() {
      _dashboardFuture = _repository.getDashboardData();
      _businessTypesFuture = _repository.getBusinessTypes();
      _salesAgentsFuture = _repository.getSalesAgents(
        perPage: 100,
        status: _salesAgentStatusFilter.isEmpty ? null : _salesAgentStatusFilter,
      );
      _salesAgentsOverviewFuture = _repository.getSalesAgentsOverview();
      _salesAgentsTabDataFuture = _loadSalesAgentsTabData();
      _reportsRefreshToken += 1;
    });
  }

  Future<void> _logout() async {
    final authState = context.read<AuthState>();
    final cartState = context.read<CartState>();
    final storeCubit = context.read<StoreCubit>();
    await _apiClient.resetSessionHeaders();
    await _storage.clearSession();
    cartState.clear();
    storeCubit.clearCurrentStore();
    await authState.setUnauthenticated();
    if (!mounted) return;
    await Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const GuestShellScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _C.red : _C.green,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
  }

  String? _requiredValidator(String fieldName, String? value) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _requiredValidator('Email', value);
    if (required != null) return required;
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(value!.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _passwordValidator(String? value) {
    final required = _requiredValidator('Password', value);
    if (required != null) return required;
    if (value!.trim().length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _slugValidator(String? value) {
    final required = _requiredValidator('Tenant Slug', value);
    if (required != null) return required;
    final pattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
    if (!pattern.hasMatch(value!.trim()))
      return 'Use lowercase letters, numbers, and hyphens only';
    return null;
  }

  Future<void> _openOnboardSheet() async {
    _onboardFormKey.currentState?.reset();
    _ownerNameController.clear();
    _ownerEmailController.clear();
    _ownerPasswordController.clear();
    _tenantNameController.clear();
    _tenantSlugController.clear();
    _isSlugManuallyEdited = false;
    _businessMode = 'product';
    _activationChannel = 'email';
    _selectedBusinessTypeId = null;
    _ownerEmailServerError = null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PremiumSheet(
          child: FutureBuilder<List<AdminBusinessTypeEntity>>(
            future: _businessTypesFuture,
            builder: (context, snapshot) {
              final businessTypes = snapshot.data ?? [];
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16, 12, 16,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                ),
                child: Form(
                  key: _onboardFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PremiumHeaderText('Onboard Owner',
                          icon: Icons.person_add_alt_1_rounded),
                      const SizedBox(height: 16),
                      _PremiumTextField(_ownerNameController, 'Owner Name',
                          icon: Icons.badge_outlined,
                          validator: (v) => _requiredValidator('Owner Name', v)),
                      const SizedBox(height: 10),
                      _PremiumTextField(_ownerEmailController, 'Email',
                          keyboardType: TextInputType.emailAddress,
                          icon: Icons.email_outlined,
                          onChanged: (_) {
                            if (_ownerEmailServerError != null)
                              setState(() => _ownerEmailServerError = null);
                          },
                          validator: (v) {
                            final e = _emailValidator(v);
                            if (e != null) return e;
                            return _ownerEmailServerError;
                          }),
                      const SizedBox(height: 10),
                      _PremiumTextField(_ownerPasswordController, 'Password',
                          obscureText: true,
                          icon: Icons.lock_outline_rounded,
                          validator: _passwordValidator),
                      const SizedBox(height: 10),
                      _PremiumTextField(_tenantNameController, 'Tenant Name',
                          icon: Icons.store_outlined,
                          validator: (v) => _requiredValidator('Tenant Name', v)),
                      const SizedBox(height: 10),
                      _PremiumTextField(_tenantSlugController, 'Tenant Slug',
                          icon: Icons.link_outlined,
                          validator: _slugValidator,
                          onChanged: (v) {
                            final generated =
                                generateSlug(_tenantNameController.text);
                            _isSlugManuallyEdited = v.trim() != generated;
                          }),
                      const SizedBox(height: 10),
                      _PremiumDropdown<String>(
                          value: _businessMode,
                          items: const ['product', 'service'],
                          label: 'Business Mode',
                          icon: Icons.settings_outlined,
                          onChanged: (v) =>
                              setState(() => _businessMode = v ?? 'product')),
                      const SizedBox(height: 10),
                      _PremiumDropdown<String>(
                          value: _activationChannel,
                          items: const ['email', 'internal', 'whatsapp'],
                          label: 'Activation Channel',
                          icon: Icons.notifications_active_outlined,
                          onChanged: (v) =>
                              setState(() => _activationChannel = v ?? 'email')),
                      const SizedBox(height: 10),
                      _PremiumDropdown<int>(
                          value: _selectedBusinessTypeId,
                          items: businessTypes.map((e) => e.id).toList(),
                          label: 'Business Type',
                          icon: Icons.category_outlined,
                          itemBuilder: (v) =>
                              businessTypes.firstWhere((e) => e.id == v).name,
                          onChanged: (v) =>
                              setState(() => _selectedBusinessTypeId = v)),
                      const SizedBox(height: 18),
                      _PremiumSubmitButton(
                        onPressed: _isSubmittingOnboard
                            ? null
                            : () => _submitOnboardOwner(sheetContext),
                        label: 'Create Owner',
                        isLoading: _isSubmittingOnboard,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (result == true) _reloadBusinessTypes();
  }

  Future<void> _submitOnboardOwner(BuildContext sheetContext) async {
    if (_isSubmittingOnboard) return;
    if (!(_onboardFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmittingOnboard = true;
      _ownerEmailServerError = null;
    });
    try {
      final result = await _repository.onboardOwner(
        ownerName: _ownerNameController.text.trim(),
        ownerEmail: _ownerEmailController.text.trim(),
        password: _ownerPasswordController.text,
        tenantName: _tenantNameController.text.trim(),
        tenantSlug: _tenantSlugController.text.trim(),
        businessMode: _businessMode,
        businessTypeId: _selectedBusinessTypeId!,
        activationChannel: _activationChannel,
      );
      final tenantIdRaw = result['tenant_id'];
      final tenantId = tenantIdRaw is num
          ? tenantIdRaw.toInt()
          : int.tryParse(tenantIdRaw?.toString() ?? '');
      if (tenantId != null && tenantId > 0) _lastOnboardedTenantId = tenantId;
      _showSnack('Owner created successfully');
      if (mounted) Navigator.pop(sheetContext, true);
    } on DioException catch (e) {
      final emailError = _extractEmailAlreadyExistsError(e);
      if (emailError != null) {
        setState(() => _ownerEmailServerError = emailError);
        _onboardFormKey.currentState?.validate();
        return;
      }
      _showSnack(
          e.response?.statusCode == 422
              ? 'Invalid input. Please check fields.'
              : 'Request failed. Please try again.',
          isError: true);
    } catch (_) {
      _showSnack('Request failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmittingOnboard = false);
    }
  }

  String _generateCode() {
    final r = Random();
    return 'NP-${r.nextInt(9000) + 1000}-${r.nextInt(9000) + 1000}';
  }

  Future<void> _openActivationCodeSheet() async {
    _activationCodeController.text = _generateCode();
    _activationDurationController.text =
        _activationDurationController.text.trim().isEmpty
            ? '12'
            : _activationDurationController.text.trim();
    _activationNoteController.text = _activationNoteController.text.trim();
    _activationCodeSubmitError = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PremiumSheet(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
            child: Form(
              key: _activationCodeFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PremiumHeaderText('Create Activation Code',
                      icon: Icons.key_rounded),
                  const SizedBox(height: 14),
                  _PremiumTextField(_activationCodeController, 'Code',
                      icon: Icons.confirmation_number_outlined,
                      validator: (v) => _requiredValidator('Code', v)),
                  const SizedBox(height: 10),
                  _PremiumTextField(
                      _activationDurationController, 'Duration Months',
                      keyboardType: TextInputType.number,
                      icon: Icons.timelapse_rounded,
                      validator: (v) {
                        final req = _requiredValidator('Duration Months', v);
                        if (req != null) return req;
                        final months = int.tryParse(v!.trim());
                        if (months == null || months < 1 || months > 120)
                          return 'Enter a valid duration between 1 and 120';
                        return null;
                      }),
                  const SizedBox(height: 10),
                  _PremiumTextField(_activationNoteController, 'Note (optional)',
                      icon: Icons.note_outlined, isRequired: false),
                  const SizedBox(height: 16),
                  if (_activationCodeSubmitError != null) ...[
                    Text(_activationCodeSubmitError!,
                        style: const TextStyle(
                            color: Color(0xFFFF8FA3),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                  ],
                  _PremiumSubmitButton(
                    onPressed: _isSubmittingCode
                        ? null
                        : () => _submitCreateCode(sheetContext),
                    label: 'Create Activation Code',
                    isLoading: _isSubmittingCode,
                    gradientColors: const [
                      Color(0xFF2E7BFF),
                      Color(0xFF4EA6FF)
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitCreateCode(BuildContext sheetContext) async {
    if (_isSubmittingCode) return;
    if (!(_activationCodeFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmittingCode = true;
      _activationCodeSubmitError = null;
    });
    final soldByUserId = await _resolveCurrentAdminUserId();
    try {
      final response = await _repository.createActivationCode(
        code: _activationCodeController.text.trim(),
        durationMonths: int.parse(_activationDurationController.text.trim()),
        note: _activationNoteController.text.trim().isEmpty
            ? null
            : _activationNoteController.text.trim(),
        soldByUserId: soldByUserId,
      );
      final createdCode = response['code'] as String?;
      if (createdCode != null && createdCode.trim().isNotEmpty)
        _lastCreatedCode = createdCode;
      if (mounted) {
        Navigator.pop(sheetContext);
        _showSnack('Activation code created successfully');
      }
    } on DioException catch (e) {
      final message =
          _extractApiErrorMessage(e) ?? 'Request failed. Please try again.';
      if (mounted) {
        setState(() => _activationCodeSubmitError = message);
        _showSnack(message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _activationCodeSubmitError = 'Request failed. Please try again.');
        _showSnack('Request failed. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmittingCode = false);
    }
  }

  Future<void> _openRedeemSheet() async {
    if (_lastCreatedCode != null && _lastCreatedCode!.trim().isNotEmpty)
      _redeemCodeController.text = _lastCreatedCode!.trim();
    if (_lastOnboardedTenantId != null && _lastOnboardedTenantId! > 0)
      _redeemTenantIdController.text = _lastOnboardedTenantId!.toString();
    _redeemSubmitError = null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PremiumSheet(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
            child: Form(
              key: _redeemFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PremiumHeaderText('Redeem Tenant + Owner',
                      icon: Icons.lock_open_rounded),
                  const SizedBox(height: 14),
                  _PremiumTextField(_redeemCodeController, 'Subscription Code',
                      icon: Icons.key_rounded,
                      validator: (v) =>
                          _requiredValidator('Subscription Code', v)),
                  const SizedBox(height: 10),
                  _PremiumTextField(_redeemTenantIdController, 'Tenant ID',
                      keyboardType: TextInputType.number,
                      icon: Icons.numbers_outlined,
                      validator: (v) {
                        final req = _requiredValidator('Tenant ID', v);
                        if (req != null) return req;
                        if (int.tryParse(v!.trim()) == null)
                          return 'Enter a valid tenant ID';
                        return null;
                      }),
                  const SizedBox(height: 16),
                  if (_redeemSubmitError != null) ...[
                    Text(_redeemSubmitError!,
                        style: const TextStyle(
                            color: Color(0xFFFF8FA3),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                  ],
                  _PremiumSubmitButton(
                    onPressed: _isSubmittingRedeem
                        ? null
                        : () => _submitRedeemTenantOwner(sheetContext),
                    label: 'Redeem Tenant + Owner',
                    isLoading: _isSubmittingRedeem,
                    gradientColors: const [
                      Color(0xFF1F7A4D),
                      Color(0xFF2E8B57)
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitRedeemTenantOwner(BuildContext sheetContext) async {
    if (_isSubmittingRedeem) return;
    if (!(_redeemFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmittingRedeem = true;
      _redeemSubmitError = null;
    });
    try {
      await _repository.redeemTenantOwner(
        code: _redeemCodeController.text.trim(),
        tenantId: int.parse(_redeemTenantIdController.text.trim()),
      );
      if (mounted) {
        Navigator.pop(sheetContext);
        _showSnack('Tenant and owner redeemed successfully');
      }
    } on DioException catch (e) {
      if (mounted)
        setState(() => _redeemSubmitError =
            _extractApiErrorMessage(e) ?? 'Request failed. Please try again.');
    } catch (_) {
      if (mounted)
        setState(() => _redeemSubmitError = 'Request failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmittingRedeem = false);
    }
  }

  Future<int?> _resolveCurrentAdminUserId() async {
    if (_currentAdminUserId != null && _currentAdminUserId! > 0)
      return _currentAdminUserId;
    try {
      final response =
          await _apiClient.get<Map<String, dynamic>>('/admin/auth/me');
      final payload = response.data ?? {};
      final data = payload['data'];
      if (data is Map) {
        final user = data['user'];
        if (user is Map) {
          final idRaw = user['id'];
          final id = idRaw is num
              ? idRaw.toInt()
              : int.tryParse(idRaw?.toString() ?? '');
          if (id != null && id > 0) {
            _currentAdminUserId = id;
            return id;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg0,
      floatingActionButton: _tab == _AdminHomeTab.salesAgents
          ? _buildCreateSalesAgentFab()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            children: [
              const _PremiumBackdrop(),
              Column(
                children: [
                  _PremiumAppBar(
                    title: 'Admin Dashboard',
                    onLogout: _logout,
                    onRefresh: _reloadBusinessTypes,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _reloadBusinessTypes,
                      color: _C.accent,
                      child: _buildTabContent(),
                    ),
                  ),
                  _PremiumBottomNavBar(
                    selectedIndex: switch (_tab) {
                      _AdminHomeTab.dashboard => 0,
                      _AdminHomeTab.salesAgents => 1,
                      _AdminHomeTab.ownerOnboarding => 2,
                      _AdminHomeTab.reports => 3,
                    },
                    onTap: (index) {
                      setState(() {
                        _tab = switch (index) {
                          0 => _AdminHomeTab.dashboard,
                          1 => _AdminHomeTab.salesAgents,
                          2 => _AdminHomeTab.ownerOnboarding,
                          _ => _AdminHomeTab.reports,
                        };
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRevenue(double value) {
    if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}m';
    if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}k';
    return '\$${value.toStringAsFixed(0)}';
  }

  String _growthBadge(AdminDashboardDataEntity data) {
    final week = data.weeklyStoresActivity.fold<int>(0, (s, i) => s + i);
    final month = data.monthlyStoresActivity.fold<int>(0, (s, i) => s + i);
    if (month == 0) return '+0.0%';
    final baseline = month / 4;
    if (baseline == 0) return '+0.0%';
    final growth = ((week - baseline) / baseline) * 100;
    return '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%';
  }

  Widget _buildTabContent() {
    return switch (_tab) {
      _AdminHomeTab.dashboard => _buildOverviewTabContent(),
      _AdminHomeTab.salesAgents => _buildSalesAgentsTabContent(),
      _AdminHomeTab.ownerOnboarding => _buildOwnerOnboardingTabContent(),
      _AdminHomeTab.reports => AdminReportsTab(
          repository: _repository,
          refreshToken: _reportsRefreshToken,
        ),
    };
  }

  Widget _buildOverviewTabContent() {
    return FutureBuilder<AdminDashboardDataEntity>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: _PremiumLoader());
        }
        if (snapshot.hasError) {
          return _buildLoadError('Failed to load dashboard data', snapshot.error);
        }
        return AdminOverviewTab(data: snapshot.data!);
      },
    );
  }

  Widget _buildSalesAgentsTabContent() {
    final future = _salesAgentsTabDataFuture ??= _loadSalesAgentsTabData();
    return FutureBuilder<
        ({
          List<AdminSalesAgentEntity> agents,
          Map<int, AdminSalesAgentOverviewEntity> overviewById
        })>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: _PremiumLoader());
        }
        if (snapshot.hasError) {
          return _buildLoadError(
              'Failed to load sales agents data', snapshot.error);
        }
        return AdminSalesAgentsTab(
          agents: snapshot.data?.agents ?? [],
          overviewById: snapshot.data?.overviewById ?? {},
          statusFilter: _salesAgentStatusFilter,
          onStatusFilterChanged: (value) {
            final normalized = value.trim();
            setState(() {
              _salesAgentStatusFilter = normalized;
              _salesAgentsFuture = _repository.getSalesAgents(
                perPage: 100,
                status: normalized.isEmpty ? null : normalized,
              );
              _salesAgentsOverviewFuture = _repository.getSalesAgentsOverview();
              _salesAgentsTabDataFuture = _loadSalesAgentsTabData();
            });
          },
          onEdit: _openEditSalesAgentSheet,
          onToggle: _toggleSalesAgentStatus,
          onDelete: _confirmDeleteSalesAgent,
          onCreate: _openCreateSalesAgentSheet,
          onRefresh: _reloadBusinessTypes,
        );
      },
    );
  }

  Widget _buildOwnerOnboardingTabContent() {
    return AdminOwnerOnboardingTab(
      onOnboardOwner: _openOnboardSheet,
      onCreateActivationCode: _openActivationCodeSheet,
      onRedeemTenantOwner: _openRedeemSheet,
      latestCode: _lastCreatedCode,
      onCopyLatestCode: () {
        if (_lastCreatedCode == null || _lastCreatedCode!.isEmpty) return;
        Clipboard.setData(ClipboardData(text: _lastCreatedCode!));
        _showSnack('Code copied');
      },
    );
  }

  Future<
      ({
        List<AdminSalesAgentEntity> agents,
        Map<int, AdminSalesAgentOverviewEntity> overviewById,
      })> _loadSalesAgentsTabData() async {
    final agents = await _salesAgentsFuture;
    final overview = await _salesAgentsOverviewFuture;
    final overviewById = <int, AdminSalesAgentOverviewEntity>{
      for (final item in overview) item.id: item,
    };
    return (agents: agents, overviewById: overviewById);
  }

  Future<void> _openEditSalesAgentSheet(AdminSalesAgentEntity item) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: item.name);
    final emailController = TextEditingController(text: item.email);
    final passwordController = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var submitting = false;
        String? emailServerError;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _PremiumSheet(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _PremiumHeaderText('Edit Sales Agent',
                          icon: Icons.edit_rounded),
                      const SizedBox(height: 12),
                      _PremiumTextField(nameController, 'Name',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => _requiredValidator('Name', v)),
                      const SizedBox(height: 10),
                      _PremiumTextField(emailController, 'Email',
                          keyboardType: TextInputType.emailAddress,
                          icon: Icons.email_outlined,
                          onChanged: (_) {
                            if (emailServerError != null)
                              setSheetState(() => emailServerError = null);
                          },
                          validator: (v) {
                            final e = _emailValidator(v);
                            if (e != null) return e;
                            return emailServerError;
                          }),
                      const SizedBox(height: 10),
                      _PremiumTextField(
                          passwordController, 'Password (optional)',
                          obscureText: true,
                          icon: Icons.lock_outline_rounded,
                          isRequired: false),
                      const SizedBox(height: 16),
                      _PremiumSubmitButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (!(formKey.currentState?.validate() ??
                                    false)) return;
                                setSheetState(() => submitting = true);
                                try {
                                  await _repository.updateSalesAgent(
                                    id: item.id,
                                    name: nameController.text.trim(),
                                    email: emailController.text.trim(),
                                    password:
                                        passwordController.text.trim().isEmpty
                                            ? null
                                            : passwordController.text.trim(),
                                  );
                                  if (mounted)
                                    Navigator.of(sheetContext).pop(true);
                                } catch (error) {
                                  if (error is DioException) {
                                    final inlineError =
                                        _extractEmailAlreadyExistsError(error);
                                    if (inlineError != null) {
                                      setSheetState(
                                          () => emailServerError = inlineError);
                                      formKey.currentState?.validate();
                                      return;
                                    }
                                  }
                                  if (mounted)
                                    _showSnack(
                                        'Request failed. Please try again.',
                                        isError: true);
                                } finally {
                                  setSheetState(() => submitting = false);
                                }
                              },
                        label: 'Save Changes',
                        isLoading: submitting,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    if (saved == true) {
      _showSnack('Sales agent updated successfully');
      _reloadBusinessTypes();
    }
  }

  Future<void> _toggleSalesAgentStatus(AdminSalesAgentEntity item) async {
    final next =
        item.status.trim().toLowerCase() == 'active' ? 'inactive' : 'active';
    try {
      await _repository.updateSalesAgentStatus(id: item.id, status: next);
      _showSnack('Sales agent status updated to $next');
      _reloadBusinessTypes();
    } catch (error) {
      _showSnack('$error', isError: true);
    }
  }

  Future<bool> _submitCreateSalesAgent() async {
    if (_isSubmittingSalesAgentCreate) return false;
    if (!(_salesAgentCreateFormKey.currentState?.validate() ?? false))
      return false;
    setState(() {
      _isSubmittingSalesAgentCreate = true;
      _salesAgentCreateEmailServerError = null;
    });
    try {
      await _repository.createSalesAgent(
        name: _salesAgentNameController.text.trim(),
        email: _salesAgentEmailController.text.trim(),
        password: _salesAgentPasswordController.text.trim(),
      );
      _salesAgentNameController.clear();
      _salesAgentEmailController.clear();
      _salesAgentPasswordController.clear();
      _salesAgentCreateEmailServerError = null;
      _showSnack('Sales agent created successfully');
      _reloadBusinessTypes();
      return true;
    } on DioException catch (error) {
      final emailError = _extractEmailAlreadyExistsError(error);
      if (emailError != null) {
        setState(() => _salesAgentCreateEmailServerError = emailError);
        _salesAgentCreateFormKey.currentState?.validate();
        return false;
      }
      _showSnack('Request failed. Please try again.', isError: true);
    } catch (error) {
      _showSnack('$error', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmittingSalesAgentCreate = false);
    }
    return false;
  }

  void _openCreateSalesAgentSheet() {
    _salesAgentCreateFormKey.currentState?.reset();
    _salesAgentNameController.clear();
    _salesAgentEmailController.clear();
    _salesAgentPasswordController.clear();
    _salesAgentCreateEmailServerError = null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return _PremiumSheet(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 24),
              child: Form(
                key: _salesAgentCreateFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PremiumHeaderText('Create Sales Agent',
                        icon: Icons.person_add_alt_1_rounded),
                    const SizedBox(height: 12),
                    _PremiumTextField(_salesAgentNameController, 'Name',
                        icon: Icons.person_outline_rounded,
                        validator: (v) => _requiredValidator('Name', v)),
                    const SizedBox(height: 10),
                    _PremiumTextField(_salesAgentEmailController, 'Email',
                        keyboardType: TextInputType.emailAddress,
                        icon: Icons.email_outlined,
                        onChanged: (_) {
                          if (_salesAgentCreateEmailServerError != null) {
                            setSheetState(() =>
                                _salesAgentCreateEmailServerError = null);
                            setState(
                                () => _salesAgentCreateEmailServerError = null);
                          }
                        },
                        validator: (v) {
                          final e = _emailValidator(v);
                          if (e != null) return e;
                          return _salesAgentCreateEmailServerError;
                        }),
                    const SizedBox(height: 10),
                    _PremiumTextField(
                        _salesAgentPasswordController, 'Password',
                        obscureText: true,
                        icon: Icons.lock_outline_rounded,
                        validator: _passwordValidator),
                    const SizedBox(height: 6),
                    const Text('Role and status are set automatically.',
                        style:
                            TextStyle(color: Color(0xFF9D9DBC), fontSize: 12)),
                    const SizedBox(height: 12),
                    _PremiumSubmitButton(
                      onPressed: _isSubmittingSalesAgentCreate
                          ? null
                          : () async {
                              final success = await _submitCreateSalesAgent();
                              if (success && mounted)
                                Navigator.of(sheetContext).maybePop();
                            },
                      label: 'Create Sales Agent',
                      isLoading: _isSubmittingSalesAgentCreate,
                      icon: Icons.person_add_alt_1_rounded,
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildCreateSalesAgentFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, right: 2),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openCreateSalesAgentSheet,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8A6BFF), Color(0xFF5E49D9)],
                ),
                border: Border.all(
                    color: const Color(0xFFB8A8FF).withOpacity(0.35),
                    width: 1.2),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))
                ],
              ),
              child: const Center(
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 30)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSalesAgent(AdminSalesAgentEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _PremiumConfirmDialog(
        title: 'Delete Sales Agent',
        content: 'Are you sure you want to delete ${item.name}?',
        onConfirm: () => Navigator.of(dialogContext).pop(true),
        onCancel: () => Navigator.of(dialogContext).pop(false),
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteSalesAgent(id: item.id);
      _showSnack('Sales agent deleted successfully');
      _reloadBusinessTypes();
    } catch (error) {
      _showSnack('$error', isError: true);
    }
  }

  String? _extractEmailAlreadyExistsError(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != 409 && statusCode != 422) return null;
    final data = error.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final errors = map['errors'];
      if (errors is Map) {
        final emailErrors = errors['email'];
        if (emailErrors is List && emailErrors.isNotEmpty)
          return 'Email already exists';
      }
      final message = map['message']?.toString().toLowerCase() ?? '';
      if (message.contains('email') &&
          (message.contains('taken') || message.contains('exist')))
        return 'Email already exists';
    }
    return null;
  }

  String? _extractApiErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message =
          Map<String, dynamic>.from(data)['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  Widget _buildLoadError(String title, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _C.red, size: 48),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: _C.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('$error',
                style: const TextStyle(color: _C.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            _PremiumActionButton(
              label: 'Retry',
              onTap: _reloadBusinessTypes,
              gradient: const [_C.accent, _C.accentBlue],
            ),
          ],
        ),
      ),
    );
  }

  // ── Activity chart helper ──────────────────────────────────────────────────

  Widget _buildActivityCard(AdminDashboardDataEntity data) {
    final stores = _range == 'Week'
        ? data.weeklyStoresActivity
        : data.monthlyStoresActivity;
    final owners = _range == 'Week'
        ? data.weeklyOwnersActivity
        : data.monthlyOwnersActivity;
    final length = min(stores.length, owners.length);

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Platform Activity',
                        style: TextStyle(
                            color: _C.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      _range == 'Week'
                          ? 'Last 7 days breakdown'
                          : 'Last 30 days breakdown',
                      style: const TextStyle(
                          color: _C.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _PremiumRangeToggle(
                  value: _range,
                  onChanged: (next) => setState(() => _range = next)),
            ],
          ),
          const SizedBox(height: 16),
          // ── Legend ─────────────────────────────────────────────────────────
          Row(
            children: const [
              _PremiumLegendDot(color: _C.chartPurple, label: 'New Stores'),
              SizedBox(width: 16),
              _PremiumLegendDot(color: _C.chartBlue, label: 'New Owners'),
            ],
          ),
          const SizedBox(height: 14),
          // ── Bar Chart ──────────────────────────────────────────────────────
          _BarChart(
            storeValues: stores.take(length).map((e) => e.toDouble()).toList(),
            ownerValues: owners.take(length).map((e) => e.toDouble()).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(AdminDashboardDataEntity data) {
    final palette = <Color>[
      _C.chartPurple,
      _C.chartBlue,
      _C.chartTeal,
      _C.chartOrange,
      _C.chartPink,
    ];
    final segments = data.businessTypeDistribution
        .asMap()
        .entries
        .map((e) => _PieSegment(
              color: palette[e.key % palette.length],
              value: e.value.count.toDouble(),
              label: e.value.name,
            ))
        .toList();
    final total = segments.fold<double>(0, (s, i) => s + i.value);

    return _PremiumCard(
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Transform.scale(
              scale: v,
              child: Opacity(
                opacity: v,
                child: CustomPaint(
                  size: const Size(130, 130),
                  painter: _PremiumPiePainter(segments: segments),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Business Types',
                    style: TextStyle(
                        color: _C.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 12),
                if (segments.isEmpty)
                  const Text('No distribution data',
                      style:
                          TextStyle(color: _C.textSecondary, fontSize: 12))
                else
                  ...segments.take(5).map((seg) {
                    final pct = total == 0
                        ? 0
                        : ((seg.value / total) * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: seg.color,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(seg.label,
                                style: const TextStyle(
                                    color: _C.textSecondary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text('$pct%',
                              style: TextStyle(
                                  color: seg.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(AdminDashboardDataEntity data) {
    final newStoresWeek =
        data.weeklyStoresActivity.fold<int>(0, (s, i) => s + i);
    final newOwnersWeek =
        data.weeklyOwnersActivity.fold<int>(0, (s, i) => s + i);
    final items = [
      'New owners this week: $newOwnersWeek',
      'New stores this week: $newStoresWeek',
      'Active subscriptions: ${data.activeSubscriptions}',
    ];

    return _PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity',
              style: TextStyle(
                  color: _C.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...items.asMap().entries.map((entry) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + entry.key * 100),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(20 * (1 - value), 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_C.accent, _C.accentBlue]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(entry.value,
                              style: const TextStyle(
                                  color: _C.textSecondary, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── BAR CHART ──────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.storeValues,
    required this.ownerValues,
  });

  final List<double> storeValues;
  final List<double> ownerValues;

  @override
  Widget build(BuildContext context) {
    final count = min(storeValues.length, ownerValues.length);
    if (count == 0) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('No activity data',
              style: TextStyle(color: _C.textMuted, fontSize: 13)),
        ),
      );
    }

    final maxVal = [
      ...storeValues.take(count),
      ...ownerValues.take(count),
    ].fold<double>(0, max);
    final safeMax = maxVal == 0 ? 1 : maxVal;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, _) {
        return Column(
          children: [
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(count, (i) {
                  final sH = (storeValues[i] / safeMax) * 120 * animValue;
                  final oH = (ownerValues[i] / safeMax) * 120 * animValue;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Stores bar
                              Expanded(
                                child: Container(
                                  height: max(sH, 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _C.chartPurple,
                                        _C.chartPurple.withOpacity(0.5),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              // Owners bar
                              Expanded(
                                child: Container(
                                  height: max(oH, 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        _C.chartBlue,
                                        _C.chartBlue.withOpacity(0.5),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // X-axis label
                          Text(
                            '${i + 1}',
                            style: const TextStyle(
                                color: _C.textMuted, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Baseline
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 2),
              color: _C.border,
            ),
          ],
        );
      },
    );
  }
}

// ── LINE SPARKLINE (used inside stat cards) ────────────────────────────────────

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        painter: _SparklinePainter(data: data, color: color, progress: v),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(
      {required this.data, required this.color, required this.progress});

  final List<double> data;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final maxV = data.reduce(max);
    final minV = data.reduce(min);
    final range = maxV == minV ? 1.0 : maxV - minV;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final totalPoints = (data.length * progress).ceil().clamp(2, data.length);
    final pts = data.take(totalPoints).toList();
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((pts[i] - minV) / range) * size.height;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    // fill
    final fillPath = Path.from(path)
      ..lineTo((totalPoints - 1) / (data.length - 1) * size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.progress != progress;
}

// ── KPI STAT CARD with sparkline ───────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sparkData,
    this.badge,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final List<double> sparkData;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.bg3, _C.bg2],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(badge!,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: _C.textSecondary, fontSize: 11, height: 1.3)),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            width: double.infinity,
            child: _Sparkline(data: sparkData, color: color),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED PREMIUM WIDGETS  (unchanged logic, refined styling)
// ═══════════════════════════════════════════════════════════════════════════════

class _PremiumBackdrop extends StatelessWidget {
  const _PremiumBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _C.accent.withOpacity(0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _C.accentBlue.withOpacity(0.1),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAppBar extends StatelessWidget {
  const _PremiumAppBar({
    required this.title,
    required this.onLogout,
    required this.onRefresh,
  });

  final String title;
  final VoidCallback onLogout;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 45, left: 16, right: 16, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.bg3, _C.bg2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _C.accent.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
              color: _C.accent.withOpacity(0.15),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_C.accent, _C.accentBlue]),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                    color: _C.accent.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Admin Dashboard',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _C.textPrimary),
          ),
          const Spacer(),
          _AppBarIconBtn(icon: Icons.refresh_rounded, onTap: onRefresh),
          const SizedBox(width: 8),
          _AppBarIconBtn(icon: Icons.logout_rounded, onTap: onLogout),
        ],
      ),
    );
  }
}

class _AppBarIconBtn extends StatelessWidget {
  const _AppBarIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _C.bg4,
          shape: BoxShape.circle,
          border: Border.all(color: _C.borderBright, width: 1),
        ),
        child: Icon(icon, color: _C.textSecondary, size: 18),
      ),
    );
  }
}

class _PremiumBottomNavBar extends StatelessWidget {
  const _PremiumBottomNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final Function(int) onTap;

  static const _items = [
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.support_agent_rounded, 'Agents'),
    (Icons.folder_open_rounded, 'Onboard'),
    (Icons.query_stats_rounded, 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [_C.bg3, _C.bg2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: _items.asMap().entries.map((entry) {
          final idx = entry.key;
          final (icon, label) = entry.value;
          final isSelected = selectedIndex == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [_C.accent, _C.accentBlue])
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: _C.accent.withOpacity(0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? Colors.white : _C.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : _C.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.bg3, _C.bg2]),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}

class _PremiumHeaderText extends StatelessWidget {
  const _PremiumHeaderText(this.text, {required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_C.accent, _C.accentBlue]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: _C.accent.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(text,
            style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PremiumSheet extends StatelessWidget {
  const _PremiumSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_C.bg3, _C.bg0]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: child,
    );
  }
}

class _PremiumTextField extends StatelessWidget {
  const _PremiumTextField(
    this.controller,
    this.label, {
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.isRequired = true,
    this.validator,
    this.onChanged,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool isRequired;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _C.accent, size: 19),
        filled: true,
        fillColor: _C.bg1,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.red, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.red, width: 1.5)),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              if (!isRequired) return null;
              return '$label is required';
            }
            return null;
          },
    );
  }
}

class _PremiumDropdown<T> extends StatelessWidget {
  const _PremiumDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.icon,
    required this.onChanged,
    this.itemBuilder,
  });

  final T? value;
  final List<T> items;
  final String label;
  final IconData icon;
  final void Function(T?) onChanged;
  final String Function(T)? itemBuilder;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: _C.bg3,
      iconEnabledColor: _C.accent,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _C.accent, size: 19),
        filled: true,
        fillColor: _C.bg1,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.accent, width: 1.5)),
      ),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                    itemBuilder != null ? itemBuilder!(item) : item.toString()),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Required' : null,
    );
  }
}

class _PremiumSubmitButton extends StatelessWidget {
  const _PremiumSubmitButton({
    required this.onPressed,
    required this.label,
    required this.isLoading,
    this.icon,
    this.gradientColors,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final IconData? icon;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    final colors = gradientColors ?? const [_C.accent, _C.accentBlue];
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: colors.first.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white)),
                ],
              ),
      ),
    );
  }
}

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.label,
    required this.onTap,
    required this.gradient,
  });

  final String label;
  final VoidCallback onTap;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: gradient.first.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

class _PremiumRangeToggle extends StatelessWidget {
  const _PremiumRangeToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: _C.bg1, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border, width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Week', 'Month'].map((label) {
          final isActive = label == value;
          return GestureDetector(
            onTap: () => onChanged(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [_C.accent, _C.accentBlue])
                    : null,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: isActive ? Colors.white : _C.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PremiumLegendDot extends StatelessWidget {
  const _PremiumLegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: _C.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _PremiumLoader extends StatelessWidget {
  const _PremiumLoader();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, v, _) => Transform.scale(
        scale: v,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [_C.accent, _C.accentBlue]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: _C.accent.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 5))
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
    );
  }
}

class _PremiumConfirmDialog extends StatelessWidget {
  const _PremiumConfirmDialog({
    required this.title,
    required this.content,
    required this.onConfirm,
    required this.onCancel,
  });

  final String title;
  final String content;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _C.bg3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _C.red.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _C.amber, size: 36),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(content,
                style: const TextStyle(color: _C.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _C.textSecondary,
                      side: const BorderSide(color: _C.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumMiniStat extends StatelessWidget {
  const _PremiumMiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _C.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: _C.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: _C.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ],
      ),
    );
  }
}

class _PremiumStatChip extends StatelessWidget {
  const _PremiumStatChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.bg3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _C.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: _C.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.3)),
        ],
      ),
    );
  }
}

class _PremiumSearchField extends StatelessWidget {
  const _PremiumSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: _C.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search by name or email',
        hintStyle: const TextStyle(color: _C.textMuted, fontSize: 13),
        prefixIcon:
            const Icon(Icons.search_rounded, color: _C.accent, size: 19),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: _C.textSecondary, size: 17),
                onPressed: onClear),
        filled: true,
        fillColor: _C.bg1,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.border, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _C.accent, width: 1.5)),
      ),
    );
  }
}

class _PremiumSalesAgentCard extends StatelessWidget {
  const _PremiumSalesAgentCard({
    required this.agent,
    required this.overview,
    required this.active,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final AdminSalesAgentEntity agent;
  final AdminSalesAgentOverviewEntity? overview;
  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.bg3, _C.bg2]),
        border: Border.all(
            color:
                active ? _C.green.withOpacity(0.3) : _C.border,
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_C.accent, _C.accentBlue]),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name,
                        style: const TextStyle(
                            color: _C.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(agent.email,
                        style: const TextStyle(
                            color: _C.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? _C.green.withOpacity(0.15)
                      : _C.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active
                          ? _C.green.withOpacity(0.4)
                          : _C.red.withOpacity(0.3),
                      width: 1),
                ),
                child: Text(
                  active ? 'Active' : agent.status,
                  style: TextStyle(
                      color: active ? _C.green : _C.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _PremiumMiniStat(
                      label: 'Owners Added',
                      value: '${overview?.ownersCount ?? 0}')),
              const SizedBox(width: 8),
              Expanded(
                  child: _PremiumMiniStat(
                      label: 'Stores Added',
                      value: '${overview?.storesCount ?? 0}')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.textSecondary,
                    side: const BorderSide(color: _C.borderBright),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                      active
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      size: 15),
                  label: Text(active ? 'Deactivate' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        active ? _C.red.withOpacity(0.2) : _C.green.withOpacity(0.2),
                    foregroundColor: active ? _C.red : _C.green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 15),
              label: const Text('Delete Sales Agent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.red,
                side: BorderSide(color: _C.red.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCodeResultCard extends StatelessWidget {
  const _PremiumCodeResultCard({required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _C.green.withOpacity(0.1),
          _C.green.withOpacity(0.04),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.green.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _C.green, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Latest Code: $code',
                style: const TextStyle(
                    color: _C.textPrimary, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _C.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.copy_rounded, color: _C.green, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumEmptyState extends StatelessWidget {
  const _PremiumEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_C.accent, _C.accentBlue]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: _C.accent.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5))
                ],
              ),
              child: const Icon(Icons.person_off_rounded,
                  color: Colors.white, size: 38),
            ),
            const SizedBox(height: 16),
            const Text('No sales agents found',
                style: TextStyle(
                    color: _C.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Try adjusting your filter or search',
                style: TextStyle(color: _C.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── PIE CHART ──────────────────────────────────────────────────────────────────

class _PieSegment {
  const _PieSegment(
      {required this.color, required this.value, required this.label});
  final Color color;
  final double value;
  final String label;
}

class _PremiumPiePainter extends CustomPainter {
  const _PremiumPiePainter({required this.segments});
  final List<_PieSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, i) => s + i.value);
    final rect = Offset.zero & size;
    final stroke = min(size.width, size.height) * 0.2;

    // background ring
    canvas.drawArc(
      rect.deflate(stroke / 2),
      0,
      pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = _C.bg4,
    );

    if (total <= 0) return;

    var start = -pi / 2;
    for (final seg in segments) {
      final sweep = (seg.value / total) * pi * 2;
      canvas.drawArc(
        rect.deflate(stroke / 2),
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = seg.color,
      );
      start += sweep;
    }

    // center hole label
    final center = Offset(size.width / 2, size.height / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: '${segments.length}',
        style: const TextStyle(
            color: _C.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        center - Offset(tp.width / 2, tp.height / 2 + 8));

    final tp2 = TextPainter(
      text: const TextSpan(
        text: 'types',
        style: TextStyle(color: _C.textMuted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas,
        center - Offset(tp2.width / 2, tp2.height / 2 - 12));
  }

  @override
  bool shouldRepaint(covariant _PremiumPiePainter old) =>
      old.segments != segments;
}