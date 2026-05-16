import 'package:flutter/foundation.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/sales_agent_activation_code_entity.dart';
import '../../domain/entities/sales_agent_business_type_entity.dart';
import '../../domain/entities/sales_agent_onboarding_result_entity.dart';
import '../../domain/entities/sales_agent_profile_entity.dart';
import '../../domain/entities/sales_agent_redeem_result_entity.dart';
import '../../domain/repositories/sales_agent_repository.dart';

/// State class for Sales Agent Cubit
/// Holds all the data and UI state for the sales agent feature
class SalesAgentState {
  const SalesAgentState({
    this.loading = false,
    this.submitting = false,
    this.successMessage,
    this.errorMessage,
    this.profile,
    this.businessTypes = const <SalesAgentBusinessTypeEntity>[],
    this.lastOnboarding,
    this.lastActivationCode,
    this.lastRedeemResult,
  });

  // UI State Flags
  final bool loading;      // Initial data loading state
  final bool submitting;   // Form submission state
  
  // Messages
  final String? successMessage;
  final String? errorMessage;
  
  // Data
  final SalesAgentProfileEntity? profile;
  final List<SalesAgentBusinessTypeEntity> businessTypes;
  
  // Last Operation Results
  final SalesAgentOnboardingResultEntity? lastOnboarding;
  final SalesAgentActivationCodeEntity? lastActivationCode;
  final SalesAgentRedeemResultEntity? lastRedeemResult;

  /// Creates a copy of this state with optional new values
  SalesAgentState copyWith({
    bool? loading,
    bool? submitting,
    String? successMessage,
    bool clearSuccessMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    SalesAgentProfileEntity? profile,
    List<SalesAgentBusinessTypeEntity>? businessTypes,
    SalesAgentOnboardingResultEntity? lastOnboarding,
    SalesAgentActivationCodeEntity? lastActivationCode,
    SalesAgentRedeemResultEntity? lastRedeemResult,
    bool clearLastActionData = false,
  }) {
    return SalesAgentState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      successMessage: clearSuccessMessage
          ? null
          : (successMessage ?? this.successMessage),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      profile: profile ?? this.profile,
      businessTypes: businessTypes ?? this.businessTypes,
      lastOnboarding: clearLastActionData ? null : (lastOnboarding ?? this.lastOnboarding),
      lastActivationCode: clearLastActionData
          ? null
          : (lastActivationCode ?? this.lastActivationCode),
      lastRedeemResult: clearLastActionData
          ? null
          : (lastRedeemResult ?? this.lastRedeemResult),
    );
  }
}

/// Cubit for managing Sales Agent operations
/// Handles:
/// - Profile initialization and caching
/// - Owner onboarding
/// - Activation code creation
/// - Subscription redemption
/// - Profile updates
class SalesAgentCubit extends ChangeNotifier {
  SalesAgentCubit({required SalesAgentRepository repository})
      : _repository = repository;

  // Dependencies
  final SalesAgentRepository _repository;
  
  // State
  SalesAgentState _state = const SalesAgentState();
  
  // Public getter
  SalesAgentState get state => _state;

  /// Internal method to update state and notify listeners
  void _emit(SalesAgentState state) {
    _state = state;
    notifyListeners();
  }

  // ==================== Initialization ====================
  
  /// Initializes the sales agent dashboard
  /// Fetches agent profile and business types
  Future<void> initialize() async {
    _logInfo('Initializing Sales Agent dashboard');
    
    _emit(
      _state.copyWith(
        loading: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );

    try {
      // Fetch both profile and business types in parallel for better performance
      final results = await Future.wait([
        _repository.getMe(),
        _repository.getBusinessTypes(),
      ]);
      
      final me = results[0] as SalesAgentProfileEntity;
      final types = results[1] as List<SalesAgentBusinessTypeEntity>;

      _emit(
        _state.copyWith(
          loading: false,
          profile: me,
          businessTypes: types,
          clearErrorMessage: true,
        ),
      );
      
      _logInfo('Initialization completed - Profile: ${me.email}, Business Types: ${types.length}');
    } catch (error) {
      _logError('Initialization failed', error);
      _emit(
        _state.copyWith(
          loading: false,
          errorMessage: _extractErrorMessage(error),
        ),
      );
    }
  }

  // ==================== Business Types ====================
  
  /// Refreshes the list of business types
  Future<void> refreshBusinessTypes() async {
    _logInfo('Refreshing business types');
    
    try {
      final types = await _repository.getBusinessTypes();
      _emit(
        _state.copyWith(
          businessTypes: types,
          clearErrorMessage: true,
        ),
      );
      _logInfo('Business types refreshed - Count: ${types.length}');
    } catch (error) {
      _logError('Failed to refresh business types', error);
      _emit(
        _state.copyWith(
          errorMessage: _extractErrorMessage(error),
        ),
      );
    }
  }

  // ==================== Owner Onboarding ====================
  
  /// Onboards a new owner and creates their tenant
  /// 
  /// Parameters:
  /// - [ownerName]: Full name of the owner
  /// - [ownerEmail]: Email address of the owner
  /// - [password]: Account password
  /// - [tenantName]: Name of the store/tenant
  /// - [tenantSlug]: URL-friendly identifier for the tenant
  /// - [businessMode]: 'product' or 'service'
  /// - [activationChannel]: 'email' or 'whatsapp'
  /// - [businessTypeId]: ID of the selected business type
  /// - [tenantWhatsappNumber]: WhatsApp contact number
  Future<void> onboardOwner({
    required String ownerName,
    required String ownerEmail,
    required String password,
    required String tenantName,
    required String tenantSlug,
    required String businessMode,
    required String activationChannel,
    required int businessTypeId,
    required String tenantWhatsappNumber,
  }) async {
    _logInfo('Starting owner onboarding - Email: $ownerEmail, Tenant: $tenantName');
    
    _emit(
      _state.copyWith(
        submitting: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
        clearLastActionData: true,
      ),
    );

    try {
      final result = await _repository.onboardOwner(
        ownerName: ownerName,
        ownerEmail: ownerEmail,
        password: password,
        tenantName: tenantName,
        tenantSlug: tenantSlug,
        businessMode: businessMode,
        activationChannel: activationChannel,
        businessTypeId: businessTypeId,
        tenantWhatsappNumber: tenantWhatsappNumber,
      );

      // Save tenant ID to secure storage for future reference
      await SecureStorage().saveTenantId(result.tenantId.toString());

      _emit(
        _state.copyWith(
          submitting: false,
          lastOnboarding: result,
          successMessage: 'Owner onboarded successfully',
          clearErrorMessage: true,
        ),
      );
      
      _logInfo('Owner onboarding completed - Owner ID: ${result.ownerUserId}, Tenant ID: ${result.tenantId}');
    } catch (error) {
      _logError('Owner onboarding failed', error);
      _emit(
        _state.copyWith(
          submitting: false,
          errorMessage: _extractErrorMessage(error),
        ),
      );
    }
  }

  // ==================== Activation Code ====================
  
  /// Creates a new activation code for subscription
  /// 
  /// Parameters:
  /// - [durationMonths]: Subscription duration in months
  /// - [code]: Optional custom code (auto-generated if null)
  /// - [note]: Optional note for reference
  Future<void> createActivationCode({
    required int durationMonths,
    String? code,
    String? note,
  }) async {
    final profile = _state.profile;
    
    // Validate that agent profile is loaded
    if (profile == null || profile.id <= 0) {
      _logWarning('Cannot create activation code - Profile not ready');
      _emit(
        _state.copyWith(
          errorMessage: 'Sales agent profile is not ready yet',
        ),
      );
      return;
    }

    _logInfo('Creating activation code - Duration: $durationMonths months, Agent ID: ${profile.id}');
    
    _emit(
      _state.copyWith(
        submitting: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
        clearLastActionData: true,
      ),
    );

    try {
      final result = await _repository.createActivationCode(
        durationMonths: durationMonths,
        code: code,
        note: note,
        soldByUserId: profile.id,
      );

      _emit(
        _state.copyWith(
          submitting: false,
          lastActivationCode: result,
          successMessage: 'Activation code created successfully',
          clearErrorMessage: true,
        ),
      );
      
      _logInfo('Activation code created - Code: ${result.code}');
    } catch (error) {
      _logError('Activation code creation failed', error);
      _emit(
        _state.copyWith(
          submitting: false,
          errorMessage: _extractErrorMessage(error),
        ),
      );
    }
  }

  /// Loads the latest active activation code from backend and caches it in state.
  Future<SalesAgentActivationCodeEntity?> loadLatestActiveCode() async {
    try {
      final latest = await _repository.getLatestActiveCode();
      if (latest == null) {
        return null;
      }

      _emit(
        _state.copyWith(
          lastActivationCode: latest,
          clearErrorMessage: true,
        ),
      );

      return latest;
    } catch (error) {
      _emit(
        _state.copyWith(
          errorMessage: _extractErrorMessage(error),
        ),
      );
      return null;
    }
  }

  // ==================== Subscription Redemption ====================
  
  /// Redeems a subscription using an activation code
  /// 
  /// Parameters:
  /// - [code]: Activation code to redeem
  /// - [tenantId]: ID of the tenant to activate subscription for
  Future<void> redeemSubscription({
    required String code,
    required int tenantId,
  }) async {
    _logInfo('Redeeming subscription - Code: $code, Tenant ID: $tenantId');
    
    _emit(
      _state.copyWith(
        submitting: true,
        clearErrorMessage: true,
        clearSuccessMessage: true,
        clearLastActionData: true,
      ),
    );

    try {
      final result = await _repository.redeemSubscription(
        code: code,
        tenantId: tenantId,
      );

      _emit(
        _state.copyWith(
          submitting: false,
          lastRedeemResult: result,
          successMessage: 'Subscription redeemed successfully',
          clearErrorMessage: true,
        ),
      );
      
      _logInfo('Subscription redeemed successfully - Status: ${result.status}');
    } catch (error) {
      _logError('Subscription redemption failed', error);
      _emit(
        _state.copyWith(
          submitting: false,
          errorMessage: _extractErrorMessage(error),
        ),
      );
    }
  }

  // ==================== Profile Management ====================
  
  /// Updates the local profile cache with new data
  /// Used after successful profile updates to keep UI in sync
  /// 
  /// Parameters:
  /// - [email]: New email address (optional)
  void updateProfileCache({String? email}) {
    final profile = _state.profile;
    if (profile == null) {
      _logWarning('Cannot update profile cache - Profile is null');
      return;
    }

    final normalizedEmail = email?.trim();
    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      _logWarning('Cannot update profile cache - Email is empty');
      return;
    }

    _emit(
      _state.copyWith(
        profile: SalesAgentProfileEntity(
          id: profile.id,
          name: profile.name,
          email: normalizedEmail,
          role: profile.role,
        ),
      ),
    );
    
    _logInfo('Profile cache updated - New email: $normalizedEmail');
  }

  // ==================== Session Management ====================
  
  /// Logs out the current sales agent
  Future<void> logout() {
    _logInfo('Logging out sales agent');
    return _repository.logout();
  }

  // ==================== Utility Methods ====================
  
  /// Clears all success and error messages from the state
  void clearMessages() {
    if (_state.errorMessage == null && _state.successMessage == null) {
      return;
    }
    
    _emit(
      _state.copyWith(
        clearErrorMessage: true,
        clearSuccessMessage: true,
      ),
    );
    
    _logInfo('Messages cleared');
  }

  /// Extracts a human-readable error message from various error types
  String _extractErrorMessage(dynamic error) {
    final message = error.toString();
    return message.replaceFirst('Exception: ', '');
  }

  // ==================== Logging ====================
  
  void _logInfo(String message) {
    if (kDebugMode) {
      debugPrint('📘 [SalesAgentCubit] $message');
    }
  }

  void _logWarning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [SalesAgentCubit] $message');
    }
  }

  void _logError(String message, dynamic error) {
    if (kDebugMode) {
      debugPrint('❌ [SalesAgentCubit] $message');
      debugPrint('   Error: $error');
    }
  }
}