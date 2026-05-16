import '../../domain/entities/end_user_profile_entity.dart';

class ProfileState {
  const ProfileState({
    required this.isLoading,
    this.profile,
    this.error,
  });

  final bool isLoading;
  final EndUserProfileEntity? profile;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  factory ProfileState.loading() {
    return const ProfileState(isLoading: true);
  }

  factory ProfileState.success(EndUserProfileEntity profile) {
    return ProfileState(isLoading: false, profile: profile);
  }

  factory ProfileState.error(String error) {
    return ProfileState(isLoading: false, error: error);
  }
}
