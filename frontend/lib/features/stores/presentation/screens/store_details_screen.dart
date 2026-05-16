import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../categories/data/datasources/categories_remote_data_source.dart';
import '../../../categories/data/repositories/categories_repository_impl.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/domain/entities/store_entity.dart';
import '../../../categories/domain/repositories/categories_repository.dart';
import '../../../categories/presentation/screens/create_category_screen.dart';
import '../../../auth/domain/entities/tenant_entity.dart';
import '../../../items/presentation/screens/items_screen.dart';
import '../theme/owner_theme.dart';

class StoreDetailsScreen extends StatefulWidget {
  const StoreDetailsScreen({super.key, required this.store});

  final StoreEntity store;

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  late final SecureStorage _storage;
  late final CategoriesRepository _categoriesRepository;
  late Future<List<CategoryEntity>> _categoriesFuture;
  List<TenantEntity> _userTenants = const <TenantEntity>[];
  bool _isCheckingOwnership = true;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: _storage);
    final remoteDataSource = CategoriesRemoteDataSource(apiClient: apiClient);
    _categoriesRepository = CategoriesRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
    
    // Initialize _categoriesFuture immediately with a function that checks auth
    // This ensures _categoriesFuture is NEVER uninitialized before build() is called
    _categoriesFuture = _getCategoriesFuture();
    
    // Load user tenants asynchronously (for ownership checks)
    _loadUserTenants();
  }

  /// Returns a Future that loads categories based on authentication status
  /// This Future is created synchronously in initState, ensuring _categoriesFuture is always initialized
  Future<List<CategoryEntity>> _getCategoriesFuture() async {
    final token = await _storage.getToken();
    final isLoggedIn = token != null && token.isNotEmpty;
    final idUsed = widget.store.resolvedStoreId;

    debugPrint('STORE ENTITY: ${widget.store.toString()}');

    if (!mounted) {
      return const <CategoryEntity>[];
    }

    if (isLoggedIn) {
      // Owner flow: use owner endpoint with tenant context
      return _categoriesRepository.getCategoriesByStore(idUsed);
    } else {
      // Guest flow: use /public/stores/{id}, preferring tenant_id then falling back to id
      debugPrint('Calling: /public/stores/$idUsed');
      return _categoriesRepository.getPublicCategoriesByStore(idUsed);
    }
  }

  /// Reload categories (for retry buttons and refresh operations)
  void _reloadCategories() {
    setState(() {
      _categoriesFuture = _getCategoriesFuture();
    });
  }

  Future<void> _loadUserTenants() async {
    final raw = await _storage.getUserTenants();

    if (!mounted) return;

    if (raw == null || raw.trim().isEmpty) {
      setState(() {
        _userTenants = const <TenantEntity>[];
        _isCheckingOwnership = false;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        setState(() {
          _userTenants = const <TenantEntity>[];
          _isCheckingOwnership = false;
        });
        return;
      }

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

      setState(() {
        _userTenants = parsed;
        _isCheckingOwnership = false;
      });
    } catch (_) {
      setState(() {
        _userTenants = const <TenantEntity>[];
        _isCheckingOwnership = false;
      });
    }
  }

  bool _isOwner(StoreEntity store, List<TenantEntity> userTenants) {
    return userTenants.any(
      (tenant) => tenant.id == store.resolvedStoreId && tenant.role.toLowerCase() == 'owner',
    );
  }

  bool get _canManageStore => _isOwner(widget.store, _userTenants);

  Future<void> _openCreateCategory() async {
    if (!_canManageStore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('You are not allowed to manage this store')),
        );
      return;
    }

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateCategoryScreen(storeId: widget.store.resolvedStoreId),
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Category created')));
      _reloadCategories();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        foregroundColor: palette.onBackground,
        title: const Text('Store Details'),
      ),
      body: Column(
        children: [
          _StoreHeader(store: widget.store),
          if (!_isCheckingOwnership && !_canManageStore)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Read Only',
                    style: TextStyle(
                      color: palette.onSurfaceMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<CategoryEntity>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: palette.primary),
                  );
                }

                if (snapshot.hasError) {
                  return _StoreCategoriesErrorState(onRetry: _reloadCategories);
                }

                final categories = snapshot.data ?? const <CategoryEntity>[];
                if (categories.isEmpty) {
                  return const _StoreCategoriesEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _StoreCategoryCard(
                      category: category,
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ItemsScreen(
                              categoryId: category.id,
                              categoryName: category.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !_isCheckingOwnership && _canManageStore
          ? FloatingActionButton(
              onPressed: _openCreateCategory,
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final StoreEntity store;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: palette.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: TextStyle(
                    color: palette.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (store.businessTypeName != null &&
                    store.businessTypeName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    store.businessTypeName!,
                    style: TextStyle(
                      color: palette.onSurfaceSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCategoryCard extends StatelessWidget {
  const _StoreCategoryCard({required this.category, required this.onTap});

  final CategoryEntity category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(Icons.category_rounded, color: palette.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: palette.onSurfaceSoft,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreCategoriesEmptyState extends StatelessWidget {
  const _StoreCategoriesEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return Center(
      child: Text(
        'No categories yet',
        style: TextStyle(
          color: palette.onSurfaceSoft,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StoreCategoriesErrorState extends StatelessWidget {
  const _StoreCategoriesErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load categories',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.onSurfaceSoft, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
