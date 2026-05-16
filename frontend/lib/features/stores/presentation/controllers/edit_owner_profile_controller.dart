import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../data/models/update_owner_profile_request_model.dart';
import '../../data/repositories/owner_profile_repository.dart';

class EditOwnerProfileController extends ChangeNotifier {
  EditOwnerProfileController({
    required OwnerProfileRepository profileRepository,
    required SecureStorage secureStorage,
  }) : _profileRepository = profileRepository,
       _secureStorage = secureStorage;

  final OwnerProfileRepository _profileRepository;
  final SecureStorage _secureStorage;

  bool _isSubmitting = false;
  bool _isUnauthorized = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  bool get isUnauthorized => _isUnauthorized;
  String? get errorMessage => _errorMessage;

  set errorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    String? tenantWhatsappNumber,
    String? tenantStoreImage,
    String? tenantStoreImageFilePath,
    String? password,
  }) async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _isUnauthorized = false;
    notifyListeners();

    try {
      // Build request with only non-empty fields
      final request = UpdateOwnerProfileRequestModel(
        name: name?.trim(),
        tenantWhatsappNumber: tenantWhatsappNumber?.trim(),
        tenantStoreImage: tenantStoreImage,
        tenantStoreImageFilePath: tenantStoreImageFilePath,
        password: password?.trim(),
      );

      final response = await _profileRepository.updateProfile(request);

      // Update local storage with new owner data if provided
      if (name != null && name.trim().isNotEmpty) {
        await _secureStorage.saveOwnerName(response.owner.name);
      }
      if (name != null && name.trim().isNotEmpty) {
        await _secureStorage.saveOwnerEmail(response.owner.email);
      }

      // Update tenant data in storage
      final rawTenants = await _secureStorage.getUserTenants();
      if (rawTenants != null && rawTenants.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawTenants);
          if (decoded is List) {
            final tenantId = (await _secureStorage.getTenantId())?.trim();
            for (int i = 0; i < decoded.length; i++) {
              if (decoded[i] is Map &&
                  decoded[i]['id']?.toString() == tenantId) {
                decoded[i]['name'] = response.tenant.name;
                decoded[i]['slug'] = response.tenant.slug;
                if (response.tenant.whatsappNumber != null) {
                  decoded[i]['whatsapp_number'] =
                      response.tenant.whatsappNumber;
                }
                decoded[i]['store_image'] = response.tenant.storeImage;
                break;
              }
            }
            await _secureStorage.saveUserTenants(jsonEncode(decoded));
          }
        } catch (_) {
          // Tenant update failed, but profile was updated on backend
          // Continue - the important part succeeded
        }
      }

      _isSubmitting = false;
      notifyListeners();
      return true;
    } on DioException catch (error) {
      _isSubmitting = false;
      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
      } else if (error.response != null) {
        final data = error.response?.data;
        if (data is Map && data['message'] is String) {
          _errorMessage = data['message'];
        } else {
          _errorMessage = 'Failed to update profile';
        }
      } else {
        _errorMessage = 'Failed to update profile';
      }
      notifyListeners();
      return false;
    } catch (error) {
      _isSubmitting = false;
      _errorMessage = 'Something went wrong';
      debugPrint('Update profile error: $error');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
