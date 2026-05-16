import '../entities/admin_login_credentials_entity.dart';
import '../entities/admin_session_entity.dart';

abstract class AdminAuthRepository {
  Future<AdminSessionEntity> login(AdminLoginCredentialsEntity credentials);
}
