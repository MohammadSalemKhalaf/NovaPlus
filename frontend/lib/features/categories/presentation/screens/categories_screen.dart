import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/business_types_remote_data_source.dart';
import '../../data/datasources/stores_remote_data_source.dart';
import '../../data/repositories/business_types_repository_impl.dart';
import '../../data/repositories/stores_repository_impl.dart';
import '../../domain/entities/business_type_entity.dart';
import '../../domain/entities/store_entity.dart';
import '../../domain/repositories/business_types_repository.dart';
import '../../domain/repositories/stores_repository.dart';
import '../../../stores/presentation/screens/store_details_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin {
  late final BusinessTypesRepository _businessTypesRepository;
  late final StoresRepository _storesRepository;
  late Future<List<BusinessTypeEntity>> _businessTypesFuture;
  late Future<List<StoreEntity>> _storesFuture;
  late AnimationController _headerAnimController;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int? _selectedBusinessTypeId;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final businessTypesRemoteDataSource =
      BusinessTypesRemoteDataSource(apiClient: apiClient);
    final storesRemoteDataSource = StoresRemoteDataSource(apiClient: apiClient);

    _businessTypesRepository =
      BusinessTypesRepositoryImpl(remoteDataSource: businessTypesRemoteDataSource);
    _storesRepository = StoresRepositoryImpl(remoteDataSource: storesRemoteDataSource);
    _businessTypesFuture = _businessTypesRepository.getBusinessTypes();
    _storesFuture = _loadStoresFromBackend();

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _headerAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<StoreEntity>> _loadStoresFromBackend() {
    return _storesRepository.getStores(
      businessTypeId: _selectedBusinessTypeId,
      search: _searchQuery.isNotEmpty ? _searchQuery : null,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _businessTypesFuture = _businessTypesRepository.getBusinessTypes();
      _storesFuture = _loadStoresFromBackend();
    });
  }

  Future<void> _onBusinessTypeSelected(int? businessTypeId) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedBusinessTypeId = businessTypeId;
      _storesFuture = _loadStoresFromBackend();
    });
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _storesFuture = _loadStoresFromBackend();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Stack(
        children: [
          // Background gradient orbs
          _buildBackgroundOrbs(),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with N and Browse Stores
                _buildHeader(),
                
                const SizedBox(height: 16),
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Filter Chips
                FutureBuilder<List<BusinessTypeEntity>>(
                  future: _businessTypesFuture,
                  builder: (context, snapshot) {
                    return _buildFilterChips(snapshot.data ?? const <BusinessTypeEntity>[]);
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Featured Section Label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF7B61FF), Color(0xFF2E7BFF)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'FEATURED',
                        style: TextStyle(
                          color: Color(0xFF6A6A8A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 14),
                
                // Featured Stores (Horizontal Scroll)
                SizedBox(
                  height: 180,
                  child: FutureBuilder<List<StoreEntity>>(
                    future: _storesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        final featured = snapshot.data!.take(3).toList();
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: featured.length,
                          itemBuilder: (context, index) {
                            return _FeaturedCard(
                              store: featured[index],
                              index: index,
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => StoreDetailsScreen(
                                      store: featured[index],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // All Stores Section Label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF7B61FF), Color(0xFF2E7BFF)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ALL STORES',
                        style: TextStyle(
                          color: Color(0xFF6A6A8A),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 14),
                
                // All Stores List
                Expanded(
                  child: FutureBuilder<List<StoreEntity>>(
                    future: _storesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const _LoadingState();
                      }
                      if (snapshot.hasError) {
                        return _ErrorState(onRetry: _reload);
                      }
                      final stores = snapshot.data ?? const <StoreEntity>[];

                      if (stores.isEmpty) {
                        if (_searchQuery.isNotEmpty) {
                          return const _NoResultsState();
                        }
                        return const _EmptyState();
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        itemCount: stores.length,
                        itemBuilder: (context, index) {
                          return _StoreCard(
                            store: stores[index],
                            index: index,
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => StoreDetailsScreen(
                                    store: stores[index],
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
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF6C47FF).withOpacity(0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF2E7BFF).withOpacity(0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'N',
            style: TextStyle(
              color: Color(0xFF7B61FF),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Browse Stores',
            style: TextStyle(
              color: Color(0xFFF2F2FF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _reload,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF181828)),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF8080A0),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<BusinessTypeEntity> businessTypes) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            isSelected: _selectedBusinessTypeId == null,
            onTap: () => _onBusinessTypeSelected(null),
          ),
          ...businessTypes.map(
            (businessType) => _buildFilterChip(
              label: businessType.name,
              isSelected: _selectedBusinessTypeId == businessType.id,
              onTap: () => _onBusinessTypeSelected(businessType.id),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7B61FF) : const Color(0xFF0C0C1A),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFF1C1C30),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF6A6A8A),
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// Featured Card
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.store,
    required this.index,
    required this.onTap,
  });

  final StoreEntity store;
  final int index;
  final VoidCallback onTap;

  static const List<Color> _gradients = [
    Color(0xFF7B61FF),
    Color(0xFF2E7BFF),
    Color(0xFF00C2A3),
  ];

  static const List<IconData> _icons = [
    Icons.devices_rounded,
    Icons.shopping_bag_rounded,
    Icons.headphones_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _gradients[index % _gradients.length];
    final icon = _icons[index % _icons.length];
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              store.name,
              style: const TextStyle(
                color: Color(0xFFF0F0FF),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (store.businessTypeName != null &&
                store.businessTypeName!.isNotEmpty)
              Text(
                store.businessTypeName!,
                style: const TextStyle(color: Color(0xFF4A4A65), fontSize: 12),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00C48C).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Open Now',
                style: TextStyle(
                  color: Color(0xFF00C48C),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Store Card
class _StoreCard extends StatefulWidget {
  const _StoreCard({
    required this.store,
    required this.index,
    required this.onTap,
  });

  final StoreEntity store;
  final int index;
  final VoidCallback onTap;

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _pressed = false;

  static const List<List<Color>> _gradients = [
    [Color(0xFF7B61FF), Color(0xFF4A3ACA)],
    [Color(0xFF2E7BFF), Color(0xFF1A4FB5)],
    [Color(0xFF00C2A3), Color(0xFF007A68)],
  ];

  static const List<IconData> _icons = [
    Icons.devices_rounded,
    Icons.shopping_bag_rounded,
    Icons.headphones_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 70), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = _gradients[widget.index % _gradients.length];
    final icon = _icons[widget.index % _icons.length];

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1C1C30)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            grad[0].withOpacity(0.2),
                            grad[1].withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: grad[0].withOpacity(0.3),
                        ),
                      ),
                      child: Icon(icon, color: grad[0], size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.store.name,
                            style: const TextStyle(
                              color: Color(0xFFF0F0FF),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.store.businessTypeName != null &&
                              widget.store.businessTypeName!.isNotEmpty)
                            const SizedBox(height: 4),
                          if (widget.store.businessTypeName != null &&
                              widget.store.businessTypeName!.isNotEmpty)
                            Text(
                              widget.store.businessTypeName!,
                              style: const TextStyle(
                                color: Color(0xFF6A6A8A),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF6A6A8A),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Search Field
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C30)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: Color(0xFFF0F0FF),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search stores...',
          hintStyle: const TextStyle(
            color: Color(0xFF2E2E4A),
            fontSize: 14,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF4A4A65),
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

// Loading State
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D1B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1C1C30)),
          ),
        ),
      ),
    );
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1C1C30)),
            ),
            child: const Icon(
              Icons.store_outlined,
              color: Color(0xFF4A4A65),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No stores found',
            style: TextStyle(
              color: Color(0xFFF0F0FF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try again later or adjust filters',
            style: TextStyle(color: Color(0xFF4A4A65), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// No Results State
class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1C1C30)),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: Color(0xFF4A4A65),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No stores found',
            style: TextStyle(
              color: Color(0xFFF0F0FF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different search term',
            style: TextStyle(color: Color(0xFF4A4A65), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// Error State
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF140808),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A1010)),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFFF6B6B),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to load',
              style: TextStyle(
                color: Color(0xFFF0F0FF),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4A4A65), fontSize: 14),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B61FF), Color(0xFF2E7BFF)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}