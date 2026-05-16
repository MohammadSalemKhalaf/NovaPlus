import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/cart_state.dart';
import '../../../../shared/theme/app_theme.dart';

class CartIconWithBadge extends StatefulWidget {
  const CartIconWithBadge({
    super.key,
    required this.onTap,
    this.icon = Icons.shopping_bag_outlined,
  });

  final VoidCallback onTap;
  final IconData icon;

  @override
  State<CartIconWithBadge> createState() => _CartIconWithBadgeState();
}

class _CartIconWithBadgeState extends State<CartIconWithBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.palette(context);

    return Consumer<CartState>(
      builder: (context, cartState, _) {
        final count = cartState.totalQuantity;

        if (count > _lastCount) {
          _pulseController.forward(from: 0);
        }
        _lastCount = count;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: widget.onTap,
              icon: Icon(
                widget.icon,
                size: 24,
                color: palette.onBackground,
              ),
              splashRadius: 24,
            ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 4,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: palette.surface,
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.34),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
