import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_storage.dart';

class OwnerProfileController extends ChangeNotifier {
  OwnerProfileController({required SecureStorage secureStorage})
    : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  bool _isLoading = true;
  String _ownerName = 'Owner';
  String _ownerEmail = '-';
  String _tenantName = 'My Store';
  String _tenantSlug = '';
  String _tenantWhatsappNumber = '';

  bool get isLoading => _isLoading;
  String get ownerName => _ownerName;
  String get ownerEmail => _ownerEmail;
  String get tenantName => _tenantName;
  String get tenantSlug => _tenantSlug;
  String get tenantWhatsappNumber => _tenantWhatsappNumber;

  String get storeShareUrl {
    return AppConfig.storePublicUrl(_tenantSlug);
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final ownerName = (await _secureStorage.getOwnerName() ?? '').trim();
    final ownerEmail = (await _secureStorage.getOwnerEmail() ?? '').trim();
    final tenantId = (await _secureStorage.getTenantId() ?? '').trim();
    final rawTenants = await _secureStorage.getUserTenants();

    String tenantName = 'My Store';
    String tenantSlug = '';
    String tenantWhatsappNumber = '';

    if (rawTenants != null && rawTenants.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTenants);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map && entry['id']?.toString() == tenantId) {
              final name = entry['name']?.toString().trim() ?? '';
              final slug = entry['slug']?.toString().trim() ?? '';
              final whatsapp = entry['whatsapp_number']?.toString().trim() ?? '';
              if (name.isNotEmpty) {
                tenantName = name;
              }
              if (slug.isNotEmpty) {
                tenantSlug = slug;
              }
              if (whatsapp.isNotEmpty) {
                tenantWhatsappNumber = whatsapp;
              }
              break;
            }
          }
        }
      } catch (_) {
        tenantName = 'My Store';
        tenantSlug = '';
        tenantWhatsappNumber = '';
      }
    }

    _ownerName = ownerName.isEmpty ? 'Owner' : ownerName;
    _ownerEmail = ownerEmail.isEmpty ? '-' : ownerEmail;
    _tenantName = tenantName;
    _tenantSlug = tenantSlug;
    _tenantWhatsappNumber = tenantWhatsappNumber;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final ownerName = (await _secureStorage.getOwnerName() ?? '').trim();
    final ownerEmail = (await _secureStorage.getOwnerEmail() ?? '').trim();
    final tenantId = (await _secureStorage.getTenantId() ?? '').trim();
    final rawTenants = await _secureStorage.getUserTenants();

    String tenantName = 'My Store';
    String tenantSlug = '';
    String tenantWhatsappNumber = '';

    if (rawTenants != null && rawTenants.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTenants);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map && entry['id']?.toString() == tenantId) {
              final name = entry['name']?.toString().trim() ?? '';
              final slug = entry['slug']?.toString().trim() ?? '';
              final whatsapp = entry['whatsapp_number']?.toString().trim() ?? '';
              if (name.isNotEmpty) {
                tenantName = name;
              }
              if (slug.isNotEmpty) {
                tenantSlug = slug;
              }
              if (whatsapp.isNotEmpty) {
                tenantWhatsappNumber = whatsapp;
              }
              break;
            }
          }
        }
      } catch (_) {
        tenantName = 'My Store';
        tenantSlug = '';
        tenantWhatsappNumber = '';
      }
    }

    _ownerName = ownerName.isEmpty ? 'Owner' : ownerName;
    _ownerEmail = ownerEmail.isEmpty ? '-' : ownerEmail;
    _tenantName = tenantName;
    _tenantSlug = tenantSlug;
    _tenantWhatsappNumber = tenantWhatsappNumber;
    notifyListeners();
  }
}
