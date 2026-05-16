import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/state/auth_state.dart';
import '../../../../core/storage/secure_storage.dart';
import 'sales_agent_cubit.dart';
import '../../domain/usecases/update_profile_usecase.dart';

/// Cubit for managing sales agent profile updates
/// Handles email and password updates with proper error handling
class SalesAgentUpdateProfileCubit extends ChangeNotifier {
  SalesAgentUpdateProfileCubit({
    required UpdateProfileUseCase updateProfileUseCase,
    required SecureStorage secureStorage,
    required AuthState authState,
    required SalesAgentCubit salesAgentCubit,
  })  : _updateProfileUseCase = updateProfileUseCase,
        _secureStorage = secureStorage,
        _authState = authState,
        _salesAgentCubit = salesAgentCubit;

  // Dependencies
  final UpdateProfileUseCase _updateProfileUseCase;
  final SecureStorage _secureStorage;
  final AuthState _authState;
  final SalesAgentCubit _salesAgentCubit;

  // State variables
  bool _isSubmitting = false;
  bool _isUnauthorized = false;
  String? _errorMessage;

  // Getters with documentation
  /// Returns true if a profile update is currently in progress
  bool get isSubmitting => _isSubmitting;
  
  /// Returns true if the last request failed due to unauthorized access (401)
  bool get isUnauthorized => _isUnauthorized;
  
  /// Returns the current error message if any, otherwise null
  String? get errorMessage => _errorMessage;

  /// Sets the error message and notifies listeners
  set errorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  /// Updates the sales agent's profile information
  /// 
  /// [email] - New email address (optional)
  /// [password] - New password (optional)
  /// 
  /// Returns true if the update was successful, false otherwise
  Future<bool> updateProfile({
    String? email,
    String? password,
  }) async {
    // Prevent multiple simultaneous submissions
    if (_isSubmitting) {
      _logWarning('Update already in progress, ignoring duplicate request');
      return false;
    }

    // Validate input - at least one field must be provided
    final normalizedEmail = email?.trim();
    final normalizedPassword = password?.trim();

    if (_hasNoChanges(normalizedEmail, normalizedPassword)) {
      _errorMessage = 'Please change at least one field';
      notifyListeners();
      _logInfo('Update rejected: No changes provided');
      return false;
    }

    // Reset state before starting
    _resetState();

    // Execute update
    try {
      await _performUpdate(normalizedEmail, normalizedPassword);
      
      // Update local storage and cache after successful API call
      await _updateLocalStorage(normalizedEmail);
      
      _isSubmitting = false;
      notifyListeners();
      _logInfo('Profile update completed successfully');
      return true;
      
    } on DioException catch (error) {
      _handleDioError(error);
      return false;
      
    } catch (error) {
      _handleGenericError(error);
      return false;
    }
  }

  /// Checks if no changes were provided
  bool _hasNoChanges(String? email, String? password) {
    final hasEmailChange = email != null && email.isNotEmpty;
    final hasPasswordChange = password != null && password.isNotEmpty;
    return !hasEmailChange && !hasPasswordChange;
  }

  /// Resets all state flags before starting a new update
  void _resetState() {
    _isSubmitting = true;
    _errorMessage = null;
    _isUnauthorized = false;
    notifyListeners();
  }

  /// Performs the actual API call to update profile
  Future<void> _performUpdate(String? email, String? password) async {
    await _updateProfileUseCase(
      email: email?.isNotEmpty == true ? email : null,
      password: password?.isNotEmpty == true ? password : null,
    );
  }

  /// Updates local storage and caches after successful API update
  Future<void> _updateLocalStorage(String? email) async {
    final hasEmailChange = email != null && email.isNotEmpty;
    
    if (hasEmailChange) {
      // Update secure storage
      await _secureStorage.saveOwnerEmail(email!);
      
      // Update auth state
      await _authState.updateProfile(email: email);
      
      // Update sales agent cubit cache
      _salesAgentCubit.updateProfileCache(email: email);
      
      _logInfo('Email updated in local storage and cache: $email');
    }
  }

  /// Handles Dio-specific errors with proper error extraction
  void _handleDioError(DioException error) {
    _isSubmitting = false;
    
    // Check for unauthorized access
    if (error.response?.statusCode == 401) {
      _isUnauthorized = true;
      _logWarning('Unauthorized access (401) during profile update');
    }
    
    // Extract meaningful error message from backend response
    _errorMessage = _extractBackendMessage(error) ?? 'Failed to update profile';
    notifyListeners();
    
    _logError('Dio error during profile update: ${error.message}', error);
  }

  /// Handles generic (non-Dio) errors
  void _handleGenericError(dynamic error) {
    _isSubmitting = false;
    _errorMessage = 'Failed to update profile';
    notifyListeners();
    
    _logError('Generic error during profile update', error);
  }

  /// Extracts error message from backend API response
  /// 
  /// Supports multiple response formats:
  /// - Direct 'message' field
  /// - 'errors' object with list of messages
  String? _extractBackendMessage(DioException error) {
    final data = error.response?.data;
    
    if (data == null) return null;

    // Try to extract from 'message' field
    if (data is Map && data['message'] is String) {
      final message = (data['message'] as String).trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    // Try to extract from 'errors' field
    if (data is Map && data['errors'] is Map) {
      final errors = data['errors'] as Map;
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          final first = value.first.toString().trim();
          if (first.isNotEmpty) {
            return first;
          }
        }
      }
    }

    return null;
  }

  /// Clears the current error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
    _logInfo('Error cleared');
  }

  // Logging methods (only in debug mode)
  void _logInfo(String message) {
    if (kDebugMode) {
      debugPrint('📘 [SalesAgentUpdateProfile] $message');
    }
  }

  void _logWarning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [SalesAgentUpdateProfile] $message');
    }
  }

  void _logError(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint('❌ [SalesAgentUpdateProfile] $message');
      if (error != null) {
        debugPrint('   Error details: $error');
      }
    }
  }
}