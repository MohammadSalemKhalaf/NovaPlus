import 'login_tenant_model.dart';

class LoginResponseModel {
  const LoginResponseModel({
    required this.token,
    required this.role,
    required this.tenantId,
    required this.tenants,
    required this.ownerName,
    required this.ownerEmail,
  });

  final String token;
  final String role;
  final String tenantId;
  final List<LoginTenantModel> tenants;
  final String? ownerName;
  final String? ownerEmail;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final payload = _extractPayload(json);
    final token = _readToken(payload);
    final tenants = _readTenants(payload);
    final ownerName = _readOwnerName(payload);
    final ownerEmail = _readOwnerEmail(payload);
    final role = _readRole(payload);

    return LoginResponseModel(
      token: token,
      role: role,
      tenantId: _readTenantId(
        payload,
        tenants,
        role: role,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
      ),
      tenants: tenants,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
    );
  }

  static Map<String, dynamic> _extractPayload(Map<String, dynamic> json) {
    final data = json['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return json;
  }

  static String _readToken(Map<String, dynamic> payload) {
    final tokenValue = payload['token'];

    if (tokenValue is String && tokenValue.isNotEmpty) {
      return tokenValue;
    }

    throw Exception('Login response does not include a valid token');
  }

  static List<LoginTenantModel> _readTenants(Map<String, dynamic> payload) {
    final tenantsRaw = payload['tenants'];
    if (tenantsRaw is! List) {
      return const <LoginTenantModel>[];
    }

    return tenantsRaw
        .whereType<Map>()
        .map((item) => LoginTenantModel.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static String _readRole(
    Map<String, dynamic> payload,
  ) {
    final rawUser = payload['user'];
    if (rawUser is! Map) {
      return 'end_user';
    }

    final userMap = Map<String, dynamic>.from(rawUser);
    final rawRoles = userMap['roles'];

    final normalizedRoles = rawRoles is List
        ? rawRoles
            .whereType<Object>()
            .map((role) => role.toString().trim().toLowerCase())
            .where((role) => role.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    String resolvedRole = 'end_user';
    if (normalizedRoles.contains('admin') || normalizedRoles.contains('super_admin')) {
      resolvedRole = 'admin';
    } else if (normalizedRoles.contains('sales_agent')) {
      resolvedRole = 'sales_agent';
    } else if (normalizedRoles.contains('owner') || normalizedRoles.contains('store_owner')) {
      resolvedRole = 'owner';
    }

    return resolvedRole;
  }

  static String _readTenantId(
    Map<String, dynamic> payload,
    List<LoginTenantModel> tenants, {
    required String role,
    required String? ownerName,
    required String? ownerEmail,
  }) {
    final fromCartMerge = _readTenantIdFromCartMerge(
      payload,
      role: role,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
    );
    if (fromCartMerge != null && fromCartMerge.isNotEmpty) {
      return fromCartMerge;
    }

    final fromTenants = tenants.isNotEmpty ? tenants.first.id.toString() : '';
    return fromTenants;
  }

  static String? _readTenantIdFromCartMerge(
    Map<String, dynamic> payload, {
    required String role,
    required String? ownerName,
    required String? ownerEmail,
  }) {
    final cartMerge = payload['cart_merge'];
    if (cartMerge is! Map) {
      return null;
    }

    final cart = cartMerge['cart'];
    if (cart is! Map) {
      return null;
    }

    final storesRaw = cart['stores'];
    if (storesRaw is! List || storesRaw.isEmpty) {
      return null;
    }

    final stores = storesRaw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (stores.isEmpty) {
      return null;
    }

    Map<String, dynamic>? selectedStore;
    final normalizedRole = role.trim().toLowerCase();
    final normalizedOwnerName = (ownerName ?? '').trim().toLowerCase();
    final normalizedOwnerEmail = (ownerEmail ?? '').trim().toLowerCase();

    if (normalizedRole == 'owner') {
      if (normalizedOwnerName.isNotEmpty) {
        for (final store in stores) {
          final tenantName = (store['tenant_name']?.toString() ?? '').trim().toLowerCase();
          if (tenantName.isNotEmpty && tenantName.contains(normalizedOwnerName)) {
            selectedStore = store;
            break;
          }
        }
      }

      if (selectedStore == null && normalizedOwnerEmail.isNotEmpty) {
        final emailLocalPart = normalizedOwnerEmail.split('@').first;
        if (emailLocalPart.isNotEmpty) {
          for (final store in stores) {
            final tenantName = (store['tenant_name']?.toString() ?? '').trim().toLowerCase();
            if (tenantName.isNotEmpty && tenantName.contains(emailLocalPart)) {
              selectedStore = store;
              break;
            }
          }
        }
      }

      if (selectedStore == null) {
        for (final store in stores) {
          final tenantName = (store['tenant_name']?.toString() ?? '').trim().toLowerCase();
          if (tenantName.contains('owner')) {
            selectedStore = store;
            break;
          }
        }
      }
    }

    selectedStore ??= stores.first;

    final tenantId = selectedStore['tenant_id']?.toString().trim();
    if (tenantId == null || tenantId.isEmpty) {
      return null;
    }

    return tenantId;
  }

  static String? _readOwnerName(Map<String, dynamic> payload) {
    final rawUser = payload['user'];
    if (rawUser is! Map) {
      return null;
    }

    final userMap = Map<String, dynamic>.from(rawUser);
    final rawName = userMap['name'];
    if (rawName is String && rawName.trim().isNotEmpty) {
      return rawName.trim();
    }

    return null;
  }

  static String? _readOwnerEmail(Map<String, dynamic> payload) {
    final rawUser = payload['user'];
    if (rawUser is! Map) {
      return null;
    }

    final userMap = Map<String, dynamic>.from(rawUser);
    final rawEmail = userMap['email'];
    if (rawEmail is String && rawEmail.trim().isNotEmpty) {
      return rawEmail.trim();
    }

    return null;
  }
}
