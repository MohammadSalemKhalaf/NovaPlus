import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/domain/repositories/categories_repository.dart';

enum OwnerAddSection { category, item }

class OwnerAddController extends ChangeNotifier {
  OwnerAddController({required CategoriesRepository categoriesRepository})
    : _categoriesRepository = categoriesRepository;

  final CategoriesRepository _categoriesRepository;

  OwnerAddSection _section = OwnerAddSection.category;
  bool _isLoading = true;
  bool _isSubmittingCategory = false;
  bool _isUnauthorized = false;
  String? _errorMessage;
  List<CategoryEntity> _categories = const <CategoryEntity>[];

  OwnerAddSection get section => _section;
  bool get isLoading => _isLoading;
  bool get isSubmittingCategory => _isSubmittingCategory;
  bool get isUnauthorized => _isUnauthorized;
  String? get errorMessage => _errorMessage;
  List<CategoryEntity> get categories => _categories;

  Future<void> load() async {
    _isLoading = true;
    _isUnauthorized = false;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _categoriesRepository.getCategories();
      _isLoading = false;
      notifyListeners();
    } on DioException catch (error) {
      _isLoading = false;
      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
      } else {
        _errorMessage = 'Something went wrong';
      }
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      _errorMessage = 'Something went wrong';
      notifyListeners();
    }
  }

  void setSection(OwnerAddSection value) {
    _section = value;
    notifyListeners();
  }

  Future<bool> createCategory({
    required String name,
    required String status,
  }) async {
    if (_isSubmittingCategory) {
      return false;
    }

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      _errorMessage = 'Category name is required';
      notifyListeners();
      return false;
    }

    _isSubmittingCategory = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _categoriesRepository.createCategory(
        name: normalizedName,
        slug: _slugify(normalizedName),
        status: status,
        sortOrder: 0,
      );

      _categories = await _categoriesRepository.getCategories();
      _isSubmittingCategory = false;
      notifyListeners();
      return true;
    } on DioException catch (error) {
      _isSubmittingCategory = false;
      if (error.response?.statusCode == 401) {
        _isUnauthorized = true;
        _errorMessage = null;
      } else if (error.response?.data is Map) {
        _errorMessage =
            (error.response?.data as Map)['message']?.toString() ?? 'Something went wrong';
      } else {
        _errorMessage = 'Something went wrong';
      }
      notifyListeners();
      return false;
    } catch (_) {
      _isSubmittingCategory = false;
      _errorMessage = 'Something went wrong';
      notifyListeners();
      return false;
    }
  }

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearUnauthorized() {
    _isUnauthorized = false;
    notifyListeners();
  }
}
