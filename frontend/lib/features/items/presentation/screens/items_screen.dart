import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../stores/presentation/theme/owner_theme.dart';
import 'create_item_screen.dart';
import 'item_details_screen.dart';
import '../../data/datasources/items_remote_data_source.dart';
import '../../data/repositories/items_repository_impl.dart';
import '../../domain/entities/item_entity.dart';
import '../../domain/repositories/items_repository.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key, this.categoryId, this.categoryName});
  final int? categoryId;
  final String? categoryName;

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen>
    with TickerProviderStateMixin {
  late final ItemsRepository _itemsRepository;
  late Future<List<ItemEntity>> _itemsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  late AnimationController _headerCtrl;

  final List<String> _filters = ['All', 'Phones', 'Laptops', 'Audio'];

  @override
  void initState() {
    super.initState();
    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final remoteDataSource = ItemsRemoteDataSource(apiClient: apiClient);
    _itemsRepository = ItemsRepositoryImpl(remoteDataSource: remoteDataSource);

    _itemsFuture = _itemsRepository.getItems(categoryId: widget.categoryId);

    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _itemsFuture = _itemsRepository.getItems(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        categoryId: widget.categoryId,
      );
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateItemScreen(initialCategoryId: widget.categoryId),
      ),
    );
    if (created == true && mounted) {
      _showToast('Item created successfully');
      await _loadItems();
    }
  }

  Future<void> _editItem(ItemEntity item) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => CreateItemScreen(
          initialCategoryId: widget.categoryId,
          editItemId: item.id,
          editItemData: item,
        ),
      ),
    );
    if (created == true && mounted) {
      _showToast('Item updated successfully');
      await _loadItems();
    }
  }

  Future<void> _deleteItem(ItemEntity item) async {
    if (!mounted) return;

    final palette = OwnerTheme.palette(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Delete Item',
            style: TextStyle(color: palette.onSurface),
          ),
          content: Text(
            'Are you sure you want to delete this item?',
            style: TextStyle(color: palette.onSurfaceMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: palette.onSurfaceMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: TextStyle(color: palette.error)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final storage = SecureStorage();
      final apiClient = ApiClient(secureStorage: storage);
      final remoteDataSource = ItemsRemoteDataSource(apiClient: apiClient);
      final itemsRepository = ItemsRepositoryImpl(remoteDataSource: remoteDataSource);

      await itemsRepository.deleteItem(item.id);

      if (!mounted) return;
      await _loadItems();
      _showToast('Item deleted');
    } on DioException catch (e) {
      if (!mounted) return;
      debugPrint('Delete item error: ${e.response?.data}');

      if (e.response?.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item already deleted')),
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

  void _showToast(String msg) {
    if (!mounted) return;
    final palette = OwnerTheme.palette(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: palette.success, size: 18),
              const SizedBox(width: 10),
              Text(msg,
                  style: TextStyle(color: palette.onSurface, fontWeight: FontWeight.w500)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: palette.surfaceElevated,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  List<ItemEntity> _filterItems(List<ItemEntity> items) {
    var filtered = items;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((i) =>
              i.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (i.shortDescription ?? '')
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          _buildBackgroundOrbs(palette),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(palette),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SearchField(
                    palette: palette,
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      _loadItems();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _buildFilterChips(palette),
                const SizedBox(height: 24),
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
                        'FEATURED PRODUCTS',
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
                SizedBox(
                  height: 260,
                  child: FutureBuilder<List<ItemEntity>>(
                    future: _itemsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        final featured = snapshot.data!.take(3).toList();
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: featured.length,
                          itemBuilder: (context, index) {
                            return _FeaturedItemCard(
                              item: featured[index],
                              index: index,
                              onTap: () {
                                Navigator.push<void>(
                                  context,
                                  _slideRoute(
                                    ItemDetailsScreen(item: featured[index]),
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
                        'ALL ITEMS',
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
                Expanded(
                  child: FutureBuilder<List<ItemEntity>>(
                    future: _itemsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _LoadingState(palette: palette);
                      }
                      if (snapshot.hasError) {
                        return _ErrorState(onRetry: _loadItems, palette: palette);
                      }
                      final all = snapshot.data ?? const <ItemEntity>[];
                      final items = _filterItems(all);

                      if (all.isEmpty) return _EmptyState(palette: palette);
                      if (items.isEmpty) {
                        return _NoResultsState(palette: palette);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _ItemCard(
                            item: items[index],
                            index: index,
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                _slideRoute(
                                  ItemDetailsScreen(item: items[index]),
                                ),
                              );
                            },
                            onEdit: () => _editItem(items[index]),
                            onDelete: () => _deleteItem(items[index]),
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
      floatingActionButton: _CreateFAB(onTap: _openCreate),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBackgroundOrbs(OwnerPalette palette) {
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
                palette.primary.withValues(alpha: 0.15),
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
                palette.secondary.withValues(alpha: 0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(OwnerPalette palette) {
    final title = (widget.categoryName ?? '').trim().isNotEmpty
        ? widget.categoryName!.trim()
        : 'Items';

    final fade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              _IconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00C48C),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Open',
                          style: TextStyle(
                            color: Color(0xFF00C48C),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '·',
                          style: TextStyle(
                            color: Color(0xFF4A4A65),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            color: palette.onSurfaceMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _IconBtn(icon: Icons.refresh_rounded, onTap: _loadItems),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(OwnerPalette palette) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedFilter = filter;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? palette.primary
                      : palette.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : palette.border,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : palette.onSurfaceMuted,
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  PageRouteBuilder<void> _slideRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }
}

class _FeaturedItemCard extends StatelessWidget {
  const _FeaturedItemCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  final ItemEntity item;
  final int index;
  final VoidCallback onTap;

  static const List<Color> _gradients = [
    Color(0xFF7B61FF),
    Color(0xFF2E7BFF),
    Color(0xFF00C2A3),
  ];

  String? _formatPrice(ItemPriceEntity? price) {
    if (price == null || (price.basePriceAmount ?? '').isEmpty) return null;
    final cur = (price.currencyCode ?? '').trim();
    return cur.isEmpty ? '\$${price.basePriceAmount}' : '${price.basePriceAmount} $cur';
  }

  @override
  Widget build(BuildContext context) {
    final color = _gradients[index % _gradients.length];
    final price = item.prices.isNotEmpty ? item.prices.first : null;
    final priceText = _formatPrice(price);

    final primaryImageUrl = item.primaryImage?.url ?? '';
    final imagePath = primaryImageUrl.trim().isNotEmpty
        ? primaryImageUrl
        : (item.images.isNotEmpty ? item.images.first.storagePath : null);
    final imageUrl = ImageHelper.build(imagePath?.trim());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
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
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: const Color(0xFF0C0C1A),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFF131325),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF2E2E4A),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.image_rounded,
                            color: Color(0xFF2E2E4A),
                            size: 32,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_rounded,
                          color: Color(0xFF2E2E4A),
                          size: 32,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF0F0FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (priceText != null)
                    Text(
                      priceText,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    required this.item,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final ItemEntity item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _pressed = false;

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

  String? _formatPrice(ItemPriceEntity? price) {
    if (price == null || (price.basePriceAmount ?? '').isEmpty) return null;
    final cur = (price.currencyCode ?? '').trim();
    return cur.isEmpty ? '\$${price.basePriceAmount}' : '${price.basePriceAmount} $cur';
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.item.prices.isNotEmpty ? widget.item.prices.first : null;
    final priceText = _formatPrice(price);

    final primaryImageUrl = widget.item.primaryImage?.url ?? '';
    final imagePath = primaryImageUrl.trim().isNotEmpty
        ? primaryImageUrl
        : (widget.item.images.isNotEmpty ? widget.item.images.first.storagePath : null);
    final imageUrl = ImageHelper.build(imagePath?.trim());

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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1C1C30)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0C1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1C1C30)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFF131325),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF2E2E4A),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.image_rounded,
                                    color: Color(0xFF2E2E4A),
                                    size: 28,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.image_rounded,
                                  color: Color(0xFF2E2E4A),
                                  size: 28,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFF0F0FF),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if ((widget.item.shortDescription ?? '').isNotEmpty)
                            Text(
                              widget.item.shortDescription!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6A6A8A),
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (priceText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  const Color(0xFF00C2A3).withOpacity(0.12),
                                  const Color(0xFF007A68).withOpacity(0.08),
                                ]),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF00C2A3).withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                priceText,
                                style: const TextStyle(
                                  color: Color(0xFF00C2A3),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
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
                      child: PopupMenuButton(
                        onSelected: (value) {
                          if (value == 'edit') {
                            widget.onEdit();
                          } else if (value == 'delete') {
                            widget.onDelete();
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
                        child: const Icon(
                          Icons.more_vert,
                          color: Color(0xFF6A6A8A),
                          size: 16,
                        ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.palette,
    required this.controller,
    required this.onChanged,
  });

  final OwnerPalette palette;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: palette.onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: TextStyle(
            color: palette.onSurfaceSoft,
            fontSize: 14,
          ),
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded,
            color: palette.onSurfaceMuted,
            size: 20,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, color: palette.onSurfaceMuted, size: 18),
      ),
    );
  }
}

class _CreateFAB extends StatefulWidget {
  const _CreateFAB({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CreateFAB> createState() => _CreateFABState();
}

class _CreateFABState extends State<_CreateFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
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
    return FadeTransition(
      opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack)),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFF2E7BFF)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B3FE8).withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Create Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.palette});

  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 94,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette});

  final OwnerPalette palette;

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
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.border),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: palette.onSurfaceMuted,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No items found',
            style: TextStyle(
              color: palette.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Items will appear here once added',
            style: TextStyle(color: palette.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.palette});

  final OwnerPalette palette;

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
              color: palette.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.border),
            ),
            child: Icon(
              Icons.search_off_rounded,
              color: palette.onSurfaceMuted,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No results found',
            style: TextStyle(
              color: palette.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: palette.onSurfaceMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.palette});

  final VoidCallback onRetry;
  final OwnerPalette palette;

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
                color: palette.errorSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.error.withValues(alpha: 0.45)),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: palette.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to load',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.onSurfaceMuted, fontSize: 14),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.primary, palette.secondary],
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
