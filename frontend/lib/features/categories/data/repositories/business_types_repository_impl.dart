import '../../domain/entities/business_type_entity.dart';
import '../../domain/repositories/business_types_repository.dart';
import '../datasources/business_types_remote_data_source.dart';

class BusinessTypesRepositoryImpl implements BusinessTypesRepository {
  BusinessTypesRepositoryImpl({
    required BusinessTypesRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final BusinessTypesRemoteDataSource _remoteDataSource;

  @override
  Future<List<BusinessTypeEntity>> getBusinessTypes() async {
    final response = await _remoteDataSource.getBusinessTypes();

    if (!response.success) {
      throw Exception(
        response.message.isNotEmpty
            ? response.message
            : 'Failed to fetch business types',
      );
    }

    return response.data
        .map(
          (item) => BusinessTypeEntity(
            id: item.id,
            name: item.name,
            slug: item.slug,
          ),
        )
        .toList(growable: false);
  }
}
