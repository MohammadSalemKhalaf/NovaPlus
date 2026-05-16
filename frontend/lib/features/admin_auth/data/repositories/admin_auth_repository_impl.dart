import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/admin_login_credentials_entity.dart';
import '../../domain/entities/admin_session_entity.dart';
import '../../domain/repositories/admin_auth_repository.dart';
import '../datasources/admin_auth_remote_data_source.dart';
import '../models/admin_login_request_model.dart';

class AdminAuthRepositoryImpl implements AdminAuthRepository {
  AdminAuthRepositoryImpl({
    required AdminAuthRemoteDataSource remoteDataSource,
    required SecureStorage secureStorage,
  }) : _remoteDataSource = remoteDataSource,
       _secureStorage = secureStorage;

  final AdminAuthRemoteDataSource _remoteDataSource;
  final SecureStorage _secureStorage;

  @override
  Future<AdminSessionEntity> login(AdminLoginCredentialsEntity credentials) async {
    final request = AdminLoginRequestModel(
      email: credentials.email,
      password: credentials.password,
    );

    final response = await _remoteDataSource.login(request);
    await _secureStorage.saveAdminToken(response.token);

    return AdminSessionEntity(token: response.token);
  }
}
