import '../../../../core/api/api_client.dart';
import '../../domain/entities/end_user_profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<EndUserProfileEntity> getProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/enduser/auth/profile',
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty profile response');
    }

    final success = responseData['success'] == true;
    if (!success) {
      final message = responseData['message']?.toString();
      throw Exception(message ?? 'Failed to fetch profile');
    }

    final payload = responseData['data'];
    if (payload is! Map) {
      throw Exception('Invalid profile payload');
    }

    final data = Map<String, dynamic>.from(payload);
    final rawRoles = data['roles'];
    final roles = rawRoles is List
        ? rawRoles.map((role) => role.toString()).toList(growable: false)
        : const <String>[];

    return EndUserProfileEntity(
      id: (data['id'] as num?)?.toInt() ?? 0,
      name: data['name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      status: data['status']?.toString() ?? 'inactive',
      roles: roles,
    );
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> fields) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/enduser/auth/profile',
      data: fields,
    );

    final responseData = response.data;
    if (responseData == null) {
      throw Exception('Empty update profile response');
    }

    final success = responseData['success'] == true;
    if (!success) {
      final message = responseData['message']?.toString();
      throw Exception(message ?? 'Failed to update profile');
    }
  }
}
