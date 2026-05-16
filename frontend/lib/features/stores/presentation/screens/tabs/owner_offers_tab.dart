import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/image_helper.dart';
import '../../../../offers/domain/entities/offer_entity.dart';
import '../offer_form_screen.dart';
import '../../controllers/owner_offers_controller.dart';
import '../../theme/owner_theme.dart';

class OwnerOffersTab extends StatefulWidget {
  const OwnerOffersTab({
    super.key,
    required this.controller,
    required this.onUnauthorized,
  });

  final OwnerOffersController controller;
  final VoidCallback onUnauthorized;

  @override
  State<OwnerOffersTab> createState() => _OwnerOffersTabState();
}

class _OwnerOffersTabState extends State<OwnerOffersTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdates);
    widget.controller.load();
  }

  @override
  void didUpdateWidget(covariant OwnerOffersTab oldWidget) {
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
    if (!mounted) {
      return;
    }

    if (widget.controller.isUnauthorized) {
      widget.controller.clearUnauthorized();
      widget.onUnauthorized();
      return;
    }

    final actionMessage = widget.controller.consumeActionMessage();
    if (actionMessage != null && actionMessage.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(actionMessage),
            behavior: SnackBarBehavior.floating,
            backgroundColor: widget.controller.isActionError
                ? const Color(0xFFEF4444).withValues(alpha: 0.9)
                : const Color(0xFF10B981).withValues(alpha: 0.9),
          ),
        );
    }
  }

  Future<void> _openCreateOffer() async {
    final currentTheme = Theme.of(context);
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => Theme(
          data: currentTheme,
          child: const OfferFormScreen(),
        ),
      ),
    );

    if (created == true && mounted) {
      await widget.controller.load();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Offer created successfully')),
        );
    }
  }

  Future<void> _openEditOffer(OfferEntity offer) async {
    final currentTheme = Theme.of(context);
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => Theme(
          data: currentTheme,
          child: OfferFormScreen(offer: offer),
        ),
      ),
    );

    if (updated == true && mounted) {
      await widget.controller.load();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Offer updated successfully')),
        );
    }
  }

  Future<void> _confirmDeleteOffer(OfferEntity offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteConfirmationDialog(title: offer.title),
    );

    if (confirmed == true) {
      await widget.controller.deleteOffer(offer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final offers = controller.filteredOffers;

        if (controller.isLoading) {
          return const _LoadingState();
        }

        if (controller.errorMessage != null) {
          return _ErrorState(
            message: controller.errorMessage!,
            onRetry: controller.load,
          );
        }

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
                      _OfferSummaryCard(
                        palette: palette,
                        totalOffers: controller.offers.length,
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        palette: palette,
                        controller: _searchController,
                        onChanged: controller.setSearchQuery,
                      ),
                      const SizedBox(height: 12),
                      _StatusFilterChips(
                        palette: palette,
                        selectedStatus: controller.selectedStatus,
                        onSelected: controller.setSelectedStatus,
                      ),
                      const SizedBox(height: 16),
                      _ActionsRow(
                        palette: palette,
                        onCreateOffer: _openCreateOffer,
                      ),
                      const SizedBox(height: 16),
                      _StatsRow(
                        palette: palette,
                        totalOffers: controller.offers.length,
                        filteredCount: offers.length,
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.offers.isEmpty)
                const SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'No offers yet',
                    subtitle: 'Create your first promotion to highlight a discount.',
                  ),
                )
              else if (offers.isEmpty)
                const SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'No matching offers',
                    subtitle: 'Try another status or search term.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final offer = offers[index];
                        return _OfferCard(
                          offer: offer,
                          isDeleting: controller.isDeleteInProgress(offer.id),
                          onEditPressed: () => _openEditOffer(offer),
                          onDeletePressed: () => _confirmDeleteOffer(offer),
                        );
                      },
                      childCount: offers.length,
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

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.palette});

  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offers',
          style: TextStyle(
            color: palette.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage discounts and promotions',
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

class _OfferSummaryCard extends StatelessWidget {
  const _OfferSummaryCard({
    required this.palette,
    required this.totalOffers,
  });

  final OwnerPalette palette;
  final int totalOffers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [palette.surfaceElevated, palette.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.local_offer_rounded,
              color: palette.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalOffers offer${totalOffers == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: palette.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Keep promotions current and easy to manage.',
                  style: TextStyle(
                    color: palette.onSurfaceMuted,
                    fontSize: 12,
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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: palette.onSurface),
      decoration: InputDecoration(
        hintText: 'Search offers',
        hintStyle: TextStyle(color: palette.onSurfaceSoft),
        prefixIcon: Icon(Icons.search_rounded, color: palette.onSurfaceMuted),
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
      ),
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.palette,
    required this.selectedStatus,
    required this.onSelected,
  });

  final OwnerPalette palette;
  final String selectedStatus;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final statuses = <String>['all', 'draft', 'active', 'archived'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final selected = selectedStatus == status;
        return ChoiceChip(
          label: Text(status == 'all' ? 'All' : status),
          selected: selected,
          onSelected: (_) => onSelected(status),
          labelStyle: TextStyle(
            color: selected ? Colors.white : palette.onSurfaceMuted,
            fontWeight: FontWeight.w600,
          ),
          selectedColor: palette.primary,
          backgroundColor: palette.surface,
          side: BorderSide(color: palette.border),
        );
      }).toList(growable: false),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.palette, required this.onCreateOffer});

  final OwnerPalette palette;
  final VoidCallback onCreateOffer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onCreateOffer,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Offer'),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.palette,
    required this.totalOffers,
    required this.filteredCount,
  });

  final OwnerPalette palette;
  final int totalOffers;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    final isFiltered = totalOffers != filteredCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 16,
            color: palette.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$totalOffers offer${totalOffers != 1 ? 's' : ''}',
            style: TextStyle(
              color: palette.onSurface,
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
              style: TextStyle(
                color: palette.primary,
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

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.isDeleting,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  final OfferEntity offer;
  final bool isDeleting;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    final imageUrl = ImageHelper.build(offer.image);
    final hasDiscount = offer.hasDiscount;
    final discountLabel = hasDiscount
        ? '${offer.discountValue}${offer.discountType == 'percentage' ? '%' : ''} ${offer.discountType == 'percentage' ? 'off' : 'discount'}'
        : 'No discount set';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl == null
                ? Icon(
                    Icons.local_offer_outlined,
                    color: palette.primary,
                  )
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(
                        Icons.local_offer_outlined,
                        color: palette.primary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offer.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: offer.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  offer.description?.trim().isNotEmpty == true
                      ? offer.description!
                      : 'No description provided',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  discountLabel,
                  style: TextStyle(
                    color: palette.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateRangeLabel(offer.startsAt, offer.endsAt),
                  style: TextStyle(
                    color: palette.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEditPressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.onSurface,
                          side: BorderSide(color: palette.border),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isDeleting ? null : onDeletePressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.error,
                          side: BorderSide(color: palette.errorSoft),
                        ),
                        icon: isDeleting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateRangeLabel(DateTime? startsAt, DateTime? endsAt) {
    final startLabel = _formatDate(startsAt) ?? 'No start date';
    final endLabel = _formatDate(endsAt) ?? 'No end date';
    return '$startLabel • $endLabel';
  }

  String? _formatDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    final year = value.year.toString();
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    final normalized = status.trim().toLowerCase();
    final isActive = normalized == 'active';
    final isDraft = normalized == 'draft';

    final background = isActive
        ? palette.successSoft
        : isDraft
            ? palette.warningSoft
            : palette.errorSoft;
    final foreground = isActive
        ? palette.success
        : isDraft
            ? palette.warning
            : palette.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        normalized.isEmpty ? 'unknown' : normalized,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: palette.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.onSurfaceMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

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
            'Loading offers...',
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            const SizedBox(height: 16),
            Text(
              'Unable to load offers',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 18,
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteConfirmationDialog extends StatelessWidget {
  const _DeleteConfirmationDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        'Delete offer?',
        style: TextStyle(color: palette.onSurface),
      ),
      content: Text(
        'This will remove "$title" from your offers list.',
        style: TextStyle(color: palette.onSurfaceMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Delete',
            style: TextStyle(color: palette.error),
          ),
        ),
      ],
    );
  }
}
