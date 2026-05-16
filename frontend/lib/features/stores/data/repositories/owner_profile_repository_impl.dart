import '../datasources/owner_profile_remote_data_source.dart';
import '../models/update_owner_profile_request_model.dart';
import '../models/update_owner_profile_response_model.dart';
import 'owner_profile_repository.dart';

class OwnerProfileRepositoryImpl implements OwnerProfileRepository {
  OwnerProfileRepositoryImpl({required OwnerProfileRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final OwnerProfileRemoteDataSource _remoteDataSource;

  @override
  Future<UpdateOwnerProfileResponseModel> updateProfile(
    UpdateOwnerProfileRequestModel request,
  ) async {
    return _remoteDataSource.updateProfile(request);
  }
}
