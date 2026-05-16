import '../models/update_owner_profile_request_model.dart';
import '../models/update_owner_profile_response_model.dart';

abstract interface class OwnerProfileRepository {
  Future<UpdateOwnerProfileResponseModel> updateProfile(
    UpdateOwnerProfileRequestModel request,
  );
}
