import '../entities/login_credentials_entity.dart';
import '../entities/auth_session_entity.dart';

abstract class AuthRepository {
  /// Authenticate user.
  /// 
  /// If login credentials include a device_id, the user is treated as a guest
  /// becoming an authenticated user, and cart merge will be triggered after login.
  Future<AuthSessionEntity> login(LoginCredentialsEntity credentials);

  /// Get authenticated user's profile with role information
  Future<String> getProfile();
}
