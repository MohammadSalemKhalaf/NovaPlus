import '../repositories/sales_agent_repository.dart';

class UpdateProfileUseCase {
  UpdateProfileUseCase(this._repository);

  final SalesAgentRepository _repository;

  Future<void> call({
    String? email,
    String? password,
  }) {
    return _repository.updateProfile(
      email: email,
      password: password,
    );
  }
}