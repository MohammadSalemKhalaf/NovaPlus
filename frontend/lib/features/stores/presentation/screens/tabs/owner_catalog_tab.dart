import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/storage/secure_storage.dart';
import '../../../../../core/utils/image_helper.dart';
import '../../../../categories/domain/entities/category_entity.dart';
import '../../../../items/domain/entities/item_entity.dart';
import '../../../../items/presentation/screens/create_item_screen.dart';
import '../../controllers/owner_catalog_controller.dart';
import '../../theme/owner_theme.dart';

/// Main catalog management tab for store owners
class OwnerCatalogTab extends StatefulWidget {
  const OwnerCatalogTab({
    super.key,
    required this.controller,
    required this.onUnauthorized,
  });

  final OwnerCatalogController controller;
  final VoidCallback onUnauthorized;

  @override
  State<OwnerCatalogTab> createState() => _OwnerCatalogTabState();
}

class _OwnerCatalogTabState extends State<OwnerCatalogTab> {
  final TextEditingController _searchController = TextEditingController();
  final SecureStorage _secureStorage = SecureStorage();

  String _storeName = 'Your Store';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdates);
    widget.controller.load();
    _loadStoreName();
  }

  @override
  void didUpdateWidget(covariant OwnerCatalogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerUpdates);
      widget.controller.addListener(_handleControllerUpdates);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdates);
    _searchController.dispose();
    super.dispose();
  }

  void _handleControllerUpdates() {
    if (!mounted) return;

    if (widget.controller.isUnauthorized) {
      widget.controller.clearUnauthorized();
      widget.onUnauthorized();
    }

    final actionMessage = widget.controller.consumeActionMessage();
    if (actionMessage != null && actionMessage.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              actionMessage,
              style: const TextStyle(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: widget.controller.isActionError
              ? const Color(0xFFEF4444).withValues(alpha: 0.9)
              : const Color(0xFF10B981).withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
    }
  }

  Future<void> _loadStoreName() async {
    final tenantId = (await _secureStorage.getTenantId() ?? '').trim();
    final rawTenants = await _secureStorage.getUserTenants();

    String resolvedStoreName = '';

    if (rawTenants != null && rawTenants.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTenants);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map) continue;
            final id = entry['id']?.toString().trim() ?? '';
            if (tenantId.isNotEmpty && id == tenantId) {
              final name = entry['name']?.toString().trim() ?? '';
              if (name.isNotEmpty) {
                resolvedStoreName = name;
                break;
              }
            }
          }
          if (resolvedStoreName.isEmpty && decoded.isNotEmpty) {
            final first = decoded.first;
            if (first is Map) {
              resolvedStoreName = first['name']?.toString().trim() ?? '';
            }
          }
        }
      } catch (_) {
        resolvedStoreName = '';
      }
    }

    if (resolvedStoreName.isEmpty) {
      resolvedStoreName = (await _secureStorage.getOwnerName() ?? '').trim();
    }

    if (mounted) {
      setState(() {
        _storeName =
            resolvedStoreName.isEmpty ? 'Your Store' : resolvedStoreName;
      });
    }
  }

  Future<void> _openEditItem(ItemEntity item) async {
    final currentTheme = Theme.of(context);
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => Theme(
          data: currentTheme,
          child: CreateItemScreen(
            item: item,
            isEdit: true,
            editItemId: item.id,
            editItemData: item,
            initialCategoryId: item.categoryId,
          ),
        ),
      ),
    );
    if (updated == true) {
      await widget.controller.load();
    }
  }

  Future<void> _confirmDeleteItem(ItemEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteConfirmationDialog(),
    );
    if (confirmed == true) {
      await widget.controller.deleteItem(item);
    }
  }

  Future<void> _openApplyOfferSheet() async {
    final controller = widget.controller;

    if (!controller.hasSelectedItems) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Select at least one item first'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    if (controller.offers.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No active offers available'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    int? selectedOfferId;
    String searchQuery = '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final normalizedQuery = searchQuery.trim().toLowerCase();
            final filteredOffers = controller.offers.where((offer) {
              if (normalizedQuery.isEmpty) {
                return true;
              }

              final title = offer.title.toLowerCase();
              final description = (offer.description ?? '').toLowerCase();
              return title.contains(normalizedQuery) ||
                  description.contains(normalizedQuery);
            }).toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apply Offer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${controller.selectedItemsCount} selected item${controller.selectedItemsCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF9A9AA8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E0E16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A35)),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setStateSheet(() => searchQuery = value);
                        },
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF7C5CFF),
                          ),
                          hintText: 'Search offers...',
                          hintStyle: TextStyle(color: Color(0xFF6B6B7A)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: filteredOffers.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'No matching offers',
                                  style: TextStyle(color: Color(0xFF9A9AA8)),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredOffers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final offer = filteredOffers[index];
                                final isSelected = selectedOfferId == offer.id;
                                final discountValue = offer.discountValue;
                                final discountText = discountValue == null
                                    ? 'No discount value'
                                    : offer.discountType == 'percentage'
                                        ? '${discountValue.toString()}%'
                                        : '${discountValue.toString()} off';

                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setStateSheet(() => selectedOfferId = offer.id);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF171723),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF7C5CFF)
                                            : const Color(0xFF2A2A35),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                offer.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                discountText,
                                                style: const TextStyle(
                                                  color: Color(0xFF10B981),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle
                                              : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? const Color(0xFF7C5CFF)
                                              : const Color(0xFF6B6B7A),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedOfferId == null || controller.isApplyingOffer
                            ? null
                            : () async {
                                await controller.applyOfferToSelectedItems(selectedOfferId!);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C5CFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: controller.isApplyingOffer
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Apply to selected items',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
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

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;

        if (controller.isLoading) {
          return const _LoadingState();
        }

        if (controller.errorMessage != null) {
          return _ErrorState(
            message: controller.errorMessage!,
            onRetry: controller.load,
          );
        }

        final items = controller.filteredItems;

        return RefreshIndicator(
          onRefresh: controller.load,
          color: palette.primary,
          backgroundColor: palette.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PageHeader(palette: palette),
                      const SizedBox(height: 20),
                      _StoreHeaderCard(storeName: _storeName),
                      const SizedBox(height: 20),
                      _CatalogSearchField(
                        controller: _searchController,
                        onChanged: controller.setSearchQuery,
                      ),
                      const SizedBox(height: 16),
                      _CategoryFilterChips(
                        selectedId: controller.selectedCategoryId,
                        categories: controller.categories,
                        onCategorySelected: controller.setSelectedCategory,
                      ),
                      const SizedBox(height: 20),
                      _StatsRow(
                        palette: palette,
                        totalItems: controller.items.length,
                        filteredCount: items.length,
                      ),
                      const SizedBox(height: 12),
                      _SelectionActionBar(
                        selectedCount: controller.selectedItemsCount,
                        onClear: controller.clearSelectedItems,
                        onApplyOffer: _openApplyOfferSheet,
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.items.isEmpty)
                const SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No items yet',
                    subtitle: 'Use the Add tab to create your first item.',
                  ),
                )
              else if (items.isEmpty)
                const SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'No matching items',
                    subtitle: 'Try another category or search term.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _CatalogItemCard(
                        item: items[index],
                        isSelected:
                          controller.isItemSelected(items[index].id),
                        isDeleting:
                            controller.isDeleteInProgress(items[index].id),
                        onSelectToggle: () =>
                          controller.toggleItemSelection(items[index].id),
                        onEditPressed: () => _openEditItem(items[index]),
                        onDeletePressed: () =>
                            _confirmDeleteItem(items[index]),
                      ),
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Page Header
// ============================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.palette});

  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catalog',
          style: TextStyle(
            color: palette.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage your store inventory',
          style: TextStyle(
            color: palette.onSurfaceMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Stats Row
// ============================================================================

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.palette,
    required this.totalItems,
    required this.filteredCount,
  });

  final OwnerPalette palette;
  final int totalItems;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    final isFiltered = totalItems != filteredCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 16,
            color: Color(0xFF7C5CFF),
          ),
          const SizedBox(width: 6),
          Text(
            '$totalItems item${totalItems != 1 ? 's' : ''}',
            style: const TextStyle(
              color: Color(0xFFD4D4E6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: palette.onSurfaceSoft,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$filteredCount shown',
              style: const TextStyle(
                color: Color(0xFF7C5CFF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.selectedCount,
    required this.onClear,
    required this.onApplyOffer,
  });

  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onApplyOffer;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: TextStyle(
                color: selectedCount > 0
                    ? palette.onSurface
                    : palette.onSurfaceSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: selectedCount > 0 ? onClear : null,
            child: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: selectedCount > 0 ? onApplyOffer : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.local_offer_rounded, size: 16),
            label: const Text(
              'Apply Offer',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Loading State
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF7C5CFF),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading catalog...',
            style: TextStyle(
              color: Color(0xFF9A9AA8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Error State
// ============================================================================

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: palette.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load catalog',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.onSurfaceMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Empty State
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: palette.primary, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.onSurfaceMuted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Store Header Card
// ============================================================================

class _StoreHeaderCard extends StatelessWidget {
  const _StoreHeaderCard({required this.storeName});

  final String storeName;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [palette.surfaceElevated, palette.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [palette.primary, palette.secondary],
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.store_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Store Owner • Active',
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text(
                  'Active',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Search Field
// ============================================================================

class _CatalogSearchField extends StatelessWidget {
  const _CatalogSearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: palette.onSurface, fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: palette.primary,
            size: 22,
          ),
          hintText: 'Search items by name...',
          hintStyle: TextStyle(
            color: palette.onSurfaceSoft,
            fontSize: 15,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: palette.onSurfaceMuted,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

// ============================================================================
// Category Filter Chips
// ============================================================================

class _CategoryFilterChips extends StatelessWidget {
  const _CategoryFilterChips({
    required this.selectedId,
    required this.categories,
    required this.onCategorySelected,
  });

  final int? selectedId;
  final List<CategoryEntity> categories;
  final ValueChanged<int?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            isSelected: selectedId == null,
            onTap: () => onCategorySelected(null),
          ),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _FilterChip(
                label: category.name,
                isSelected: selectedId == category.id,
                onTap: () => onCategorySelected(category.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.primary
              : palette.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? palette.primary
                : palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : palette.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Delete Confirmation Dialog
// ============================================================================

class _DeleteConfirmationDialog extends StatelessWidget {
  const _DeleteConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.border),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: palette.error,
            size: 28,
          ),
          SizedBox(width: 12),
          Text(
            'Delete Item',
            style: TextStyle(
              color: palette.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete this item? This action cannot be undone.',
        style: TextStyle(
          color: palette.onSurfaceMuted,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: palette.onSurfaceMuted),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Delete',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Item Card — edit/delete stacked vertically on the right
// ============================================================================

class _CatalogItemCard extends StatelessWidget {
  const _CatalogItemCard({
    required this.item,
    required this.isSelected,
    required this.isDeleting,
    required this.onSelectToggle,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  final ItemEntity item;
  final bool isSelected;
  final bool isDeleting;
  final VoidCallback onSelectToggle;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;

  String _getPriceText() {
    final currency = item.currency?.trim() ?? '';
    if (item.price != null && currency.isNotEmpty) {
      return '${item.price} $currency';
    }
    if (item.price != null) return '${item.price}';

    final firstPrice = item.prices.isNotEmpty ? item.prices.first : null;
    final priceAmount = (firstPrice?.basePriceAmount ?? '').trim();
    final priceCurrency = (firstPrice?.currencyCode ?? '').trim();

    if (priceAmount.isEmpty) return 'No price';
    return priceCurrency.isEmpty
        ? priceAmount
        : '$priceAmount $priceCurrency';
  }

  String? _getImageUrl() {
    final directImage = (item.image ?? '').trim();
    final primaryImageUrl = (item.primaryImage?.url ?? '').trim();
    final imagePath = directImage.isNotEmpty
        ? directImage
        : (primaryImageUrl.isNotEmpty
            ? primaryImageUrl
            : (item.images.isNotEmpty
                ? item.images.first.storagePath
                : null));
    return ImageHelper.build(imagePath);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    final imageUrl = _getImageUrl();
    final priceText = _getPriceText();
    final status =
        item.status.trim().isEmpty ? 'inactive' : item.status.trim();
    final isActive = status.toLowerCase() == 'active';

    const double cardHeight = 122.0;
    const double actionColWidth = 52.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: cardHeight,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isSelected ? palette.primary : palette.border,
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image ────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 88,
                height: 88,
                child: imageUrl == null
                    ? Container(
                        color: palette.surfaceAlt,
                        child: const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: Color(0xFF4A4A5A),
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: palette.surfaceAlt,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7C5CFF),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: palette.surfaceAlt,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 32,
                              color: Color(0xFF4A4A5A),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),

          // ── Info ─────────────────────────────────
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: onSelectToggle,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18,
                            color: isSelected
                                ? const Color(0xFF7C5CFF)
                                : const Color(0xFF6B6B7A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isSelected ? 'Selected' : 'Select item',
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF7C5CFF)
                                  : const Color(0xFF9A9AA8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? palette.successSoft
                              : palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.currency_rupee,
                              size: 11,
                              color: isActive ? palette.success : palette.onSurfaceMuted,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              priceText,
                              style: TextStyle(
                                color: isActive ? palette.success : palette.onSurfaceMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status badge
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? palette.successSoft
                                    : palette.errorSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.circle
                                        : Icons.circle_outlined,
                                    size: 8,
                                    color: isActive ? palette.success : palette.error,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: isActive ? palette.success : palette.error,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Vertical separator ────────────────────
          Container(
            width: 1,
            color: const Color(0xFF2A2A35),
          ),

          // ── Action column: Edit (top) / Delete (bottom) ──
          SizedBox(
            width: actionColWidth,
            child: Column(
              children: [
                // Edit button — top half
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isDeleting ? null : onEditPressed,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(19),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: isDeleting
                              ? const Color(0xFF7C5CFF).withValues(alpha: 0.3)
                              : const Color(0xFF7C5CFF),
                        ),
                      ),
                    ),
                  ),
                ),

                // Thin divider
                Container(
                  height: 1,
                  color: const Color(0xFF2A2A35),
                ),

                // Delete button — bottom half
                Expanded(
                  child: isDeleting
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        )
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onDeletePressed,
                            borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(19),
                            ),
                            // Custom trash icon matching the reference image
                            child: Center(
                              child: _TrashIcon(
                                color: const Color(0xFFEF4444),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Custom Trash Icon — matches the reference image style
// ============================================================================

class _TrashIcon extends StatelessWidget {
  const _TrashIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TrashIconPainter(color: color),
    );
  }
}

class _TrashIconPainter extends CustomPainter {
  _TrashIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.095
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Lid handle (small rectangle on top center)
    final handleLeft = w * 0.38;
    final handleRight = w * 0.62;
    final handleTop = h * 0.03;
    final handleBottom = h * 0.16;
    final handleRRect = RRect.fromLTRBR(
      handleLeft,
      handleTop,
      handleRight,
      handleBottom,
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(handleRRect, paint);

    // Lid line (horizontal line across full width)
    canvas.drawLine(
      Offset(w * 0.08, h * 0.22),
      Offset(w * 0.92, h * 0.22),
      paint,
    );

    // Body (rounded rectangle)
    final bodyRRect = RRect.fromLTRBR(
      w * 0.14,
      h * 0.27,
      w * 0.86,
      h * 0.95,
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(bodyRRect, paint);

    // Inner lines (3 vertical bars inside the body)
    final lineTop = h * 0.38;
    final lineBottom = h * 0.84;

    // Left bar
    canvas.drawLine(
      Offset(w * 0.35, lineTop),
      Offset(w * 0.35, lineBottom),
      paint,
    );
    // Center bar
    canvas.drawLine(
      Offset(w * 0.50, lineTop),
      Offset(w * 0.50, lineBottom),
      paint,
    );
    // Right bar
    canvas.drawLine(
      Offset(w * 0.65, lineTop),
      Offset(w * 0.65, lineBottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TrashIconPainter oldDelegate) =>
      oldDelegate.color != color;
}