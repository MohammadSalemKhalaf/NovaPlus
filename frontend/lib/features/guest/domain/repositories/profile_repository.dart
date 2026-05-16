import '../entities/end_user_profile_entity.dart';

abstract class ProfileRepository {
  Future<EndUserProfileEntity> getProfile();

  Future<void> updateProfile(Map<String, dynamic> fields);
}
