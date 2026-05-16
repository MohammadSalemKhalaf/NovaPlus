import '../entities/end_user_profile_entity.dart';
import '../repositories/profile_repository.dart';

class ProfileService {
  ProfileService({required ProfileRepository repository})
      : _repository = repository;

  final ProfileRepository _repository;

  Future<EndUserProfileEntity> getProfile() {
    return _repository.getProfile();
  }

  Future<void> updateProfile(Map<String, dynamic> fields) {
    return _repository.updateProfile(fields);
  }
}
