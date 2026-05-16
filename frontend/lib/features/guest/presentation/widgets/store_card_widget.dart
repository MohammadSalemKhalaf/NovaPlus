import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/utils/image_helper.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/guest_entities.dart';

class StoreCardWidget extends StatelessWidget {
  const StoreCardWidget({
    super.key,
    required this.store,
    required this.onTap,
    this.trailing,
  });

  final GuestStoreEntity store;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.palette(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = ImageHelper.build(store.image);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? palette.surface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.08),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 70,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 10,
                      right: 2,
                      bottom: -1,
                      top: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.black.withValues(alpha: 0.22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(-0.08)
                        ..translateByDouble(-2.0, 0.0, 0.0, 1.0),
                      alignment: Alignment.center,
                      child: Container(
                        width: 92,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E36) : const Color(0xFFF2F7FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x33FFFFFF)
                                : palette.border.withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? const Color(0xFF18244A) : Colors.black)
                                  .withValues(alpha: isDark ? 0.34 : 0.12),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl != null)
                                CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const _StoreIconFallback(),
                                  errorWidget: (_, __, ___) => const _StoreIconFallback(),
                                )
                              else
                                const _StoreIconFallback(),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0x33FFFFFF),
                                      Color(0x00000000),
                                      Color(0x22000000),
                                    ],
                                    stops: [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      store.businessType?.name ?? 'Business type unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.onSurfaceMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: palette.onSurfaceMuted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreIconFallback extends StatelessWidget {
  const _StoreIconFallback();

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.palette(context);

    return Icon(
      Icons.storefront_rounded,
      color: palette.onSurfaceMuted,
      size: 28,
    );
  }
}
