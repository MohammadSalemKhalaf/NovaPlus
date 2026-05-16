import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../stores/presentation/theme/owner_theme.dart';
import '../../data/datasources/categories_remote_data_source.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../domain/repositories/categories_repository.dart';

class CreateCategoryScreen extends StatefulWidget {
  const CreateCategoryScreen({super.key, required this.storeId});

  final int storeId;

  @override
  State<CreateCategoryScreen> createState() => _CreateCategoryScreenState();
}

class _CreateCategoryScreenState extends State<CreateCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  late final SecureStorage _storage;
  late final CategoriesRepository _categoriesRepository;

  bool _isSubmitting = false;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    _storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: _storage);
    final remoteDataSource = CategoriesRemoteDataSource(apiClient: apiClient);
    _categoriesRepository = CategoriesRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _slugify(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '-');
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    await _storage.saveTenantId(widget.storeId.toString());

    final tenantId = await _storage.getTenantId();
    if (tenantId == null || tenantId.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No active tenant selected.')),
        );
      return;
    }

    final name = _nameController.text.trim();
    final slug = _slugify(name);
    if (slug.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a valid category name.')),
        );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _categoriesRepository.createCategory(
        name: name,
        slug: slug,
        status: _status,
        sortOrder: 0,
      );

      if (!mounted) return;
      Navigator.pop<bool>(context, true);
    } on DioException catch (e) {
      debugPrint('Create category validation error: ${e.response?.data}');
      if (!mounted) return;
      final responseData = e.response?.data;
      String message = 'Failed to create category';

      if (responseData is Map<String, dynamic>) {
        final backendMessage = responseData['message'];
        if (backendMessage is String && backendMessage.isNotEmpty) {
          message = backendMessage;
        }
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.onBackground,
        elevation: 0,
        title: const Text('Create Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [palette.surfaceElevated, palette.surface],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: palette.primarySoft,
                    ),
                    child: Icon(Icons.category_rounded, color: palette.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Category',
                          style: TextStyle(
                            color: palette.onSurface,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add a category to organize your products.',
                          style: TextStyle(
                            color: palette.onSurfaceMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Category Name',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: palette.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g. Drinks',
                hintStyle: TextStyle(color: palette.onSurfaceSoft),
                filled: true,
                fillColor: palette.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.primary),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.error),
                ),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Category name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Status',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status,
                  dropdownColor: palette.surface,
                  style: TextStyle(color: palette.onSurface),
                  iconEnabledColor: palette.primary,
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('active')),
                    DropdownMenuItem(value: 'archived', child: Text('archived')),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _status = value);
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Category',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
