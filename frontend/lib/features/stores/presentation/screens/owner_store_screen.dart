import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/state/store_cubit.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../categories/data/datasources/categories_remote_data_source.dart';
import '../../../categories/data/repositories/categories_repository_impl.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../categories/presentation/screens/create_category_screen.dart';
import '../../../auth/domain/entities/tenant_entity.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../guest/presentation/screens/guest_shell_screen.dart';
import '../../../items/presentation/screens/items_screen.dart';

class OwnerStoreScreen extends StatefulWidget {
  const OwnerStoreScreen({super.key});

  @override
  State<OwnerStoreScreen> createState() => _OwnerStoreScreenState();
}

class _OwnerStoreScreenState extends State<OwnerStoreScreen> {
  late final SecureStorage _storage;
  late final ApiClient _apiClient;
  late final CategoriesRepository _categoriesRepository;
  late Future<List<CategoryEntity>> _categoriesFuture;
  String? _storeName;
  String? _tenantId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorage();
    _apiClient = ApiClient(secureStorage: _storage);
    final remoteDataSource = CategoriesRemoteDataSource(apiClient: _apiClient);
    _categoriesRepository = CategoriesRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    try {
      final tenantId = await _storage.getTenantId();
      final raw = await _storage.getUserTenants();

      if (!mounted) return;

      String storeName = 'My Store';

      if (raw != null && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            final parsed = decoded
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .map(
                  (tenant) => TenantEntity(
                    id: (tenant['id'] as num?)?.toInt() ?? 0,
                    name: (tenant['name'] as String?) ?? '',
                    slug: (tenant['slug'] as String?) ?? '',
                    role: (tenant['role'] as String?) ?? '',
                  ),
                )
                .toList(growable: false);

            // Get the active tenant's name
            if (tenantId != null && parsed.isNotEmpty) {
              final activeTenant = parsed.firstWhere(
                (t) => t.id.toString() == tenantId,
                orElse: () => parsed.first,
              );
              storeName = activeTenant.name;
            }
          }
        } catch (_) {
          // Silently ignore parse errors
        }
      }

      if (!mounted) return;

      setState(() {
        _storeName = storeName;
        _tenantId = tenantId;
        _isLoading = false;
      });

      // Load categories for the owner's store
      _categoriesFuture = _categoriesRepository.getCategoriesByStore(
        int.tryParse(tenantId ?? '') ?? 0,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reloadCategories() async {
    if (_tenantId != null) {
      setState(() {
        _categoriesFuture = _categoriesRepository.getCategoriesByStore(
          int.parse(_tenantId!),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080812),
      appBar: AppBar(
        backgroundColor: const Color(0xFF10101E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Store',
              style: TextStyle(
                color: Color(0xFFF0F0FF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_storeName != null)
              Text(
                _storeName!,
                style: const TextStyle(
                  color: Color(0xFF6B6B88),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          PopupMenuButton(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10101E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF242438),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A4EFF), Color(0xFF2E7BFF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.store,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _storeName ?? 'My Store',
                                style: const TextStyle(
                                  color: Color(0xFFF0F0FF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Owner Dashboard',
                                style: TextStyle(
                                  color: Color(0xFF6B6B88),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Categories Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(
                          color: Color(0xFFF0F0FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (_tenantId != null) {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute<bool>(
                                builder: (_) => CreateCategoryScreen(
                                  storeId: int.parse(_tenantId!),
                                ),
                              ),
                            );
                            if (result ?? false) {
                              await _reloadCategories();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Category created successfully'),
                                    backgroundColor: Color(0xFF1F7A4D),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A4EFF),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text(
                          'New',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Categories List
                  FutureBuilder<List<CategoryEntity>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading categories',
                            style: TextStyle(color: Colors.red.shade400),
                          ),
                        );
                      }

                      final categories = snapshot.data ?? [];

                      if (categories.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10101E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF242438),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 48,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No categories yet',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your first category to get started',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return _buildCategoryCard(category);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryCard(CategoryEntity category) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10101E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF242438),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: Color(0xFFF0F0FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.slug,
                      style: const TextStyle(
                        color: Color(0xFF6B6B88),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: category.status == 'active'
                          ? const Color(0xFF1F7A4D).withOpacity(0.2)
                          : const Color(0xFFB00020).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category.status,
                      style: TextStyle(
                        color: category.status == 'active'
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editCategory(category);
                      } else if (value == 'delete') {
                        _deleteCategory(category);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF6B6B88),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ItemsScreen(categoryId: category.id, categoryName: category.name),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A4EFF),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              minimumSize: const Size(double.infinity, 36),
            ),
            child: const Text(
              'Manage Items',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editCategory(CategoryEntity category) async {
    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final remoteDataSource = CategoriesRemoteDataSource(apiClient: apiClient);
    final categoriesRepository = CategoriesRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );

    final nameController = TextEditingController(text: category.name);
    final slugController = TextEditingController(text: category.slug);
    String selectedStatus = category.status;
    bool isSubmitting = false;

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF10101E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Category',
                      style: TextStyle(
                        color: Color(0xFFF0F0FF),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Color(0xFFF0F0FF)),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        labelStyle: const TextStyle(color: Color(0xFF6B6B88)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF242438)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF242438)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6A4EFF)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D0D1B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: slugController,
                      style: const TextStyle(color: Color(0xFFF0F0FF)),
                      decoration: InputDecoration(
                        labelText: 'Slug',
                        labelStyle: const TextStyle(color: Color(0xFF6B6B88)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF242438)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF242438)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6A4EFF)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D0D1B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'archived', child: Text('Archived')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: const TextStyle(color: Color(0xFF6B6B88)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF242438)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF242438)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6A4EFF)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D0D1B),
                      ),
                      dropdownColor: const Color(0xFF10101E),
                      style: const TextStyle(color: Color(0xFFF0F0FF)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Category name required')),
                                  );
                                  return;
                                }

                                setState(() => isSubmitting = true);

                                try {
                                  await categoriesRepository.updateCategory(
                                    id: category.id,
                                    name: nameController.text.trim(),
                                    slug: slugController.text.trim(),
                                    status: selectedStatus,
                                    sortOrder: 0,
                                  );

                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  _reloadCategories();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Category updated successfully')),
                                  );
                                } on DioException catch (e) {
                                  debugPrint(
                                      'Update category error: ${e.response?.data}');
                                  if (!mounted) return;
                                  final message = e.response?.data is Map
                                      ? e.response?.data['message'] ??
                                          'Update failed'
                                      : 'Update failed';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => isSubmitting = false);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A4EFF),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update Category'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCategory(CategoryEntity category) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10101E),
          title: const Text(
            'Delete Category',
            style: TextStyle(color: Color(0xFFF0F0FF)),
          ),
          content: const Text(
            'This will delete the category and ALL its items. This action cannot be undone.',
            style: TextStyle(color: Color(0xFF6B6B88)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storage = SecureStorage();
      final apiClient = ApiClient(secureStorage: storage);
      final remoteDataSource = CategoriesRemoteDataSource(apiClient: apiClient);
      final categoriesRepository = CategoriesRepositoryImpl(
        remoteDataSource: remoteDataSource,
      );

      await categoriesRepository.deleteCategory(category.id);

      if (!mounted) return;
      _reloadCategories();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Category and its items deleted'),
          backgroundColor: Color(0xFF1F7A4D),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      debugPrint('Delete category error: ${e.response?.data}');

      if (e.response?.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category already deleted')),
        );
      } else {
        final message = e.response?.data is Map
            ? e.response?.data['message'] ?? 'Delete failed'
            : 'Delete failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: const Color(0xFF10101E),
        title: const Text(
          'Logout?',
          style: TextStyle(color: Color(0xFFF0F0FF)),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFF6B6B88)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final authState = context.read<AuthState>();
              final cartState = context.read<CartState>();
              final storeCubit = context.read<StoreCubit>();

              await _apiClient.resetSessionHeaders();
              await _storage.clearSession();
              cartState.clear();
              storeCubit.clearCurrentStore();
              await authState.setUnauthenticated();

              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const GuestShellScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
