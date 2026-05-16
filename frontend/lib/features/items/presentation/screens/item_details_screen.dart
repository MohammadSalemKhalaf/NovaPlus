import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/image_helper.dart';
import '../../../stores/presentation/theme/owner_theme.dart';
import '../../domain/entities/item_entity.dart';

class ItemDetailsScreen extends StatelessWidget {
  const ItemDetailsScreen({
    super.key,
    required this.item,
  });

  final ItemEntity item;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    final priceText = _formatPrice(item.prices.isNotEmpty ? item.prices.first : null);
    final hasPrice = priceText != null;

    final primaryImagePath = (item.primaryImage?.url ?? '').trim();
    final fallbackImagePath = item.images.isNotEmpty ? item.images.first.storagePath : null;
    final imagePath = primaryImagePath.isNotEmpty ? primaryImagePath : fallbackImagePath;
    final imageUrl = ImageHelper.build(imagePath);

    final shortDescription = (item.shortDescription ?? '').trim();
    final longDescription = (item.longDescription ?? '').trim();
    final defaultDescription = (item.description ?? '').trim();

    final effectiveShortDescription = shortDescription.isNotEmpty
        ? shortDescription
        : (defaultDescription.isNotEmpty ? defaultDescription : null);

    final effectiveLongDescription = longDescription.isNotEmpty
        ? longDescription
        : null;

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: palette.surface,
            foregroundColor: palette.onSurface,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroImage(imageUrl: imageUrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: palette.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: hasPrice ? const Color(0xFF0D2A18) : palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasPrice
                              ? const Color(0xFF00C2A3).withValues(alpha: 0.3)
                                : palette.border,
                          ),
                        ),
                        child: Text(
                          hasPrice ? priceText : 'No price',
                          style: TextStyle(
                            color: hasPrice ? const Color(0xFF00C2A3) : palette.onSurfaceSoft,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MetaChip(
                    icon: Icons.label_rounded,
                    text: item.status,
                  ),
                  if (effectiveShortDescription != null) ...[
                    const SizedBox(height: 22),
                    const _SectionTitle('Short Description'),
                    const SizedBox(height: 8),
                    _DescriptionCard(text: effectiveShortDescription),
                  ],
                  if (effectiveLongDescription != null) ...[
                    const SizedBox(height: 18),
                    const _SectionTitle('Long Description'),
                    const SizedBox(height: 8),
                    _DescriptionCard(text: effectiveLongDescription),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatPrice(ItemPriceEntity? price) {
    if (price == null || (price.basePriceAmount ?? '').isEmpty) {
      return null;
    }

    final currency = (price.currencyCode ?? '').trim();
    return currency.isEmpty ? price.basePriceAmount : '${price.basePriceAmount} $currency';
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.surfaceAlt, palette.surface],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.image_rounded,
            size: 68,
            color: palette.onSurfaceSoft,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (_, __) => Container(color: palette.surfaceAlt),
      errorWidget: (_, __, ___) => Container(
        color: palette.surface,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 38,
            color: palette.onSurfaceSoft,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return Text(
      text,
      style: TextStyle(
        color: palette.onSurfaceMuted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.onSurfaceMuted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: palette.onSurfaceSoft),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: palette.onSurfaceSoft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
