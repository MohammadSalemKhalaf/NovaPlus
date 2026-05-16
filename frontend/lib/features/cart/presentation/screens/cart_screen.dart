import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/state/store_cubit.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/theme/app_theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeId = context.read<StoreCubit>().currentStoreId;
      context.read<CartState>().fetchCart(storeId: storeId);
    });
  }

  Future<void> _checkout(BuildContext context, CartState cartState) async {
    final messenger = ScaffoldMessenger.of(context);
    final selectedStoreId = context.read<StoreCubit>().currentStoreId;
    final resolvedStoreId = selectedStoreId ?? cartState.currentStoreId;
    final cartSnapshot = cartState.items
        .map(
          (item) => <String, dynamic>{
            'item_id': item.itemId,
            'item_name': item.itemName,
            'quantity': item.quantity,
            'line_total': item.total,
          },
        )
        .toList(growable: false);
    final totalItemsSnapshot = cartState.totalItems;
    final totalPriceSnapshot = cartState.totalPrice;

    final url = await cartState.checkoutWhatsApp();
    if (!mounted) {
      return;
    }

    if (url == null || url.trim().isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to open WhatsApp checkout.'),
            backgroundColor: Color(0xFFB00020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Invalid WhatsApp URL.'),
            backgroundColor: Color(0xFFB00020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      if (!mounted) {
        return;
      }

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp.'),
            backgroundColor: Color(0xFFB00020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    try {
      final storage = SecureStorage();
      await storage.appendLocalOrder(<String, dynamic>{
        'id': 'WA-${DateTime.now().millisecondsSinceEpoch}',
        'source': 'whatsapp',
        'status': 'submitted_whatsapp',
        'tenant_id': resolvedStoreId,
        'items_count': totalItemsSnapshot,
        'subtotal': totalPriceSnapshot,
        'created_at': DateTime.now().toIso8601String(),
        'items': cartSnapshot,
      });
    } catch (_) {
      // Never block checkout flow if local order persistence fails.
    }

    if (resolvedStoreId != null) {
      await cartState.clearCart(storeId: resolvedStoreId);
      await cartState.fetchCart(storeId: resolvedStoreId, silent: true);
    } else {
      await cartState.clearCart();
    }

    // Defensive fallback: if backend clear didn't reflect yet, clear local UI state.
    if (cartState.items.isNotEmpty) {
      cartState.clear();
    }

    if (!mounted) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Order sent to WhatsApp and cart cleared.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.palette(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        foregroundColor: palette.onBackground,
        title: const Text('Cart'),
      ),
      body: Consumer<CartState>(
        builder: (context, cartState, _) {
          final currentStoreId = context.watch<StoreCubit>().currentStoreId;
          return RefreshIndicator(
            onRefresh: () => cartState.fetchCart(storeId: currentStoreId),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: palette.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${cartState.totalItems} item${cartState.totalItems == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: palette.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${cartState.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: palette.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (cartState.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5B4BFF),
                      ),
                    ),
                  )
                else if (cartState.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      cartState.errorMessage!,
                      style: TextStyle(
                        color: palette.onSurfaceMuted,
                        height: 1.35,
                      ),
                    ),
                  )
                else if (cartState.items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 36,
                          color: palette.onSurfaceMuted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Your cart is empty',
                          style: TextStyle(
                            color: palette.onSurfaceMuted,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ...cartState.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            _CartItemThumbnail(
                              imagePath: cartState.imageForItem(item.itemId),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName.isNotEmpty
                                      ? item.itemName
                                      : (cartState.nameForItem(item.itemId)?.isNotEmpty == true
                                        ? cartState.nameForItem(item.itemId)!
                                        : 'Item #${item.itemId}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: ${item.quantity}  •  \$${item.total.toStringAsFixed(2)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.onSurfaceMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _QtyButton(
                                        icon: Icons.remove,
                                        color: palette.onSurface,
                                        bgColor: palette.surfaceElevated,
                                        borderColor: palette.border,
                                        onTap: () => cartState.decrementItem(
                                          itemId: item.itemId,
                                          storeId: currentStoreId,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          '${item.quantity}',
                                          style: TextStyle(
                                            color: palette.onSurface,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _QtyButton(
                                        icon: Icons.add,
                                        color: palette.onSurface,
                                        bgColor: palette.surfaceElevated,
                                        borderColor: palette.border,
                                        onTap: () => cartState.incrementItem(
                                          itemId: item.itemId,
                                          storeId: currentStoreId,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => cartState.removeItem(
                                itemId: item.itemId,
                                storeId: currentStoreId,
                              ),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: palette.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              cartState.clearCart(storeId: currentStoreId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.onSurface,
                            side: BorderSide(color: palette.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Clear Cart'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _checkout(context, cartState),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Checkout WhatsApp'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class _CartItemThumbnail extends StatelessWidget {
  const _CartItemThumbnail({required this.imagePath});

  final String? imagePath;

  String? get _resolvedImage {
    final raw = imagePath?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    return '${AppConfig.storageUrl}$raw';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.palette(context);
    final image = _resolvedImage;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? Icon(Icons.inventory_2_outlined, color: palette.onSurfaceMuted)
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image_outlined,
                color: palette.onSurfaceMuted,
              ),
            ),
    );
  }
}
