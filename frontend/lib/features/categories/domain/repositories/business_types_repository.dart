import '../entities/business_type_entity.dart';

abstract class BusinessTypesRepository {
  Future<List<BusinessTypeEntity>> getBusinessTypes();
}
