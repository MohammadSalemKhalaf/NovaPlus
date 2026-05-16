import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/services/device_id_manager.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../favorites/data/favorites_api.dart';
import '../../../favorites/data/favorites_repository.dart';
import '../../../favorites/presentation/favorites_cubit.dart';
import '../../../favorites/presentation/screens/favorites_screen.dart';
import 'guest_orders_placeholder_screen.dart';
import 'guest_profile_screen.dart';
import 'guest_scan_qr_screen.dart';
import 'guest_stores_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _DT {
  // Radius
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  // Spacing
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space6 = 6;
  static const double space8 = 8;
  static const double space12 = 12;

  // Nav bar
  static const double navHeight = 80;
  static const double navIndicatorH = 52;
  static const double navIndicatorW = 60;
  static const double navIconSize = 22;
  static const double navLabelSize = 10.5;

  // Animation
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration med = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 500);
}

// ─────────────────────────────────────────────────────────────────────────────
//  COLOR PALETTE  (light + dark)
// ─────────────────────────────────────────────────────────────────────────────

class _Palette {
  final Brightness brightness;

  const _Palette._(this.brightness);

  static const _Palette light = _Palette._(Brightness.light);
  static const _Palette dark = _Palette._(Brightness.dark);

  bool get isDark => brightness == Brightness.dark;

  // ── Accent
  Color get accent => isDark ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
  Color get accentSoft =>
      isDark ? const Color(0xFF5CE1B0).withOpacity(0.18) : const Color(0xFF00A878).withOpacity(0.12);
  Color get accentGlow =>
      isDark ? const Color(0xFF5CE1B0).withOpacity(0.35) : const Color(0xFF00A878).withOpacity(0.28);

  // ── Backgrounds
  Color get bgBase => isDark ? const Color(0xFF0B0C10) : const Color(0xFFF5F6FA);
  Color get bgSurface => isDark ? const Color(0xFF141519) : const Color(0xFFFFFFFF);
  Color get bgCard => isDark ? const Color(0xFF1A1C23) : const Color(0xFFFFFFFF);
  Color get bgFloat => isDark ? const Color(0xFF1E2029) : const Color(0xFFFFFFFF);

  // ── Glass
  Color get glass =>
      isDark ? const Color(0xFF1E2029).withOpacity(0.72) : Colors.white.withOpacity(0.78);
  Color get glassBorder =>
      isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);

  // ── Orbs / decorative
  Color get orb1 => isDark ? const Color(0xFF1A3A4A) : const Color(0xFFD6F5EC);
  Color get orb2 => isDark ? const Color(0xFF0D1F35) : const Color(0xFFE0EDFF);
  Color get orb3 => isDark ? const Color(0xFF221A3A) : const Color(0xFFF0E5FF);

  // ── Text
  Color get textPrimary => isDark ? const Color(0xFFF0F0F5) : const Color(0xFF0F1117);
  Color get textSecondary => isDark ? const Color(0xFF9095A8) : const Color(0xFF6B7280);
  Color get textHint => isDark ? const Color(0xFF555B70) : const Color(0xFFB0B7C3);

  // ── Nav selected / unselected
  Color get navSelected => accent;
  Color get navUnselected =>
      isDark ? const Color(0xFF5A5F72) : const Color(0xFFA0A7B8);

  // ── Shadow
  Color get shadowDeep =>
      isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.10);
  Color get shadowLight =>
      isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.05);

  // ── Divider
  Color get divider =>
      isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHELL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class GuestShellScreen extends StatefulWidget {
  const GuestShellScreen({super.key});

  @override
  State<GuestShellScreen> createState() => _GuestShellScreenState();
}

class _GuestShellScreenState extends State<GuestShellScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final FavoritesCubit _favoritesCubit;
  late final AnimationController _bgPulse;

  @override
  void initState() {
    super.initState();
    _bgPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final favoritesApi = FavoritesApi(apiClient: apiClient);
    final favoritesRepository = FavoritesRepository(api: favoritesApi);
    _favoritesCubit = FavoritesCubit(
      repository: favoritesRepository,
      authState: context.read<AuthState>(),
    );
    _favoritesCubit.loadFavorites();
    _initializeDeviceId();
  }

  @override
  void dispose() {
    _bgPulse.dispose();
    _favoritesCubit.dispose();
    super.dispose();
  }

  Future<void> _initializeDeviceId() async {
    try {
      final secureStorage = SecureStorage();
      final deviceIdManager = DeviceIdManager(secureStorage: secureStorage);
      final deviceId = await deviceIdManager.getDeviceId();
      debugPrint('Device ID initialized: $deviceId');
      if (!mounted) return;
      await context.read<CartState>().fetchCart();
    } catch (error) {
      debugPrint('Failed to initialize device ID: $error');
    }
  }

  void _onDestinationSelected(int value) {
    HapticFeedback.selectionClick();
    setState(() => _index = value);
    if (!mounted) return;
    if (value == 0 || value == 3) _favoritesCubit.loadFavorites();
    context.read<CartState>().fetchCart();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final p = brightness == Brightness.dark ? _Palette.dark : _Palette.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: p.isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: p.bgFloat,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: p.bgFloat,
            ),
      child: ChangeNotifierProvider<FavoritesCubit>.value(
        value: _favoritesCubit,
        child: Scaffold(
          backgroundColor: p.bgBase,
          extendBody: true,
          body: Stack(
            children: [
              // ── Atmospheric background
              _AtmosphericBg(p: p, pulse: _bgPulse),

              // ── Content
              AnimatedSwitcher(
                duration: _DT.med,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.025),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
                child: IndexedStack(
                  key: ValueKey<int>(_index),
                  index: _index,
                  children: <Widget>[
                    const GuestStoresScreen(),
                    GuestScanQrScreen(isActive: _index == 1),
                    const GuestOrdersPlaceholderScreen(),
                    const FavoritesScreen(),
                    const GuestProfileScreen(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _PremiumNavBar(
            p: p,
            selectedIndex: _index,
            onDestinationSelected: _onDestinationSelected,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ATMOSPHERIC BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────

class _AtmosphericBg extends StatelessWidget {
  final _Palette p;
  final AnimationController pulse;

  const _AtmosphericBg({required this.p, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final t = pulse.value;
          return CustomPaint(
            painter: _BgPainter(p: p, t: t, size: size),
          );
        },
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final _Palette p;
  final double t;
  final Size size;

  _BgPainter({required this.p, required this.t, required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    // Base fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = p.bgBase,
    );

    final ease = Curves.easeInOut.transform(t);

    // Orb 1 – top-right
    _drawOrb(
      canvas,
      center: Offset(
        size.width * 0.82 + ease * 12,
        size.height * 0.08 - ease * 10,
      ),
      radius: size.width * 0.52,
      color: p.orb1,
    );

    // Orb 2 – bottom-left
    _drawOrb(
      canvas,
      center: Offset(
        size.width * 0.1 - ease * 10,
        size.height * 0.78 + ease * 8,
      ),
      radius: size.width * 0.45,
      color: p.orb2,
    );

    // Orb 3 – center accent
    _drawOrb(
      canvas,
      center: Offset(
        size.width * 0.55 + ease * 6,
        size.height * 0.42 - ease * 6,
      ),
      radius: size.width * 0.30,
      color: p.orb3,
    );

    // Subtle dot-grid texture
    _drawGrid(canvas, size);
  }

  void _drawOrb(Canvas canvas,
      {required Offset center, required double radius, required Color color}) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withOpacity(0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.src;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = p.isDark
          ? Colors.white.withOpacity(0.025)
          : Colors.black.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t || old.p != p;
}

// ─────────────────────────────────────────────────────────────────────────────
//  PREMIUM NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumNavBar extends StatelessWidget {
  final _Palette p;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _PremiumNavBar({
    required this.p,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const _items = [
    _NavItem(
      label: 'Stores',
      icon: Icons.storefront_outlined,
      activeIcon: Icons.storefront_rounded,
    ),
    _NavItem(
      label: 'Scan QR',
      icon: Icons.qr_code_scanner_rounded,
      activeIcon: Icons.qr_code_scanner_rounded,
    ),
    _NavItem(
      label: 'Orders',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    _NavItem(
      label: 'Favorites',
      icon: Icons.bookmark_border_rounded,
      activeIcon: Icons.bookmark_rounded,
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: _DT.navHeight + bottom,
          decoration: BoxDecoration(
            color: p.glass,
            border: Border(
              top: BorderSide(color: p.glassBorder, width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: p.shadowDeep,
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: Row(
              children: List.generate(_items.length, (i) {
                final isSelected = i == selectedIndex;
                return Expanded(
                  child: _NavButton(
                    item: _items[i],
                    isSelected: isSelected,
                    p: p,
                    onTap: () => onDestinationSelected(i),
                    isCenter: i == 1,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  NAV BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final _Palette p;
  final VoidCallback onTap;
  final bool isCenter;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.p,
    required this.onTap,
    required this.isCenter,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _iconScale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _DT.med);
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.isSelected) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _NavButton old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !old.isSelected) {
      _ctrl.animateTo(1.0);
    } else if (!widget.isSelected && old.isSelected) {
      _ctrl.animateTo(0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final selected = widget.isSelected;

          // ── Center "Scan QR" gets a special pill treatment
          if (widget.isCenter) {
            return _buildCenterButton(p, selected);
          }

          return SizedBox(
            height: _DT.navHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon + indicator pill
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow halo
                    if (selected)
                      Opacity(
                        opacity: _glow.value * 0.6,
                        child: Container(
                          width: _DT.navIndicatorW,
                          height: _DT.navIndicatorH * 0.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: p.accentGlow,
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Pill indicator
                    AnimatedContainer(
                      duration: _DT.med,
                      curve: Curves.easeOutCubic,
                      width: selected ? _DT.navIndicatorW : 0,
                      height: selected ? 36 : 0,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_DT.radiusMd),
                        color: selected ? p.accentSoft : Colors.transparent,
                        border: selected
                            ? Border.all(
                                color: p.accent.withOpacity(0.3),
                                width: 0.8,
                              )
                            : null,
                      ),
                    ),

                    // Icon
                    Transform.scale(
                      scale: selected ? _iconScale.value : 1.0,
                      child: Icon(
                        selected ? widget.item.activeIcon : widget.item.icon,
                        size: _DT.navIconSize,
                        color: selected ? p.navSelected : p.navUnselected,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: _DT.space4),

                // Label
                AnimatedDefaultTextStyle(
                  duration: _DT.fast,
                  style: TextStyle(
                    fontSize: _DT.navLabelSize,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? p.navSelected : p.navUnselected,
                    letterSpacing: selected ? 0.3 : 0.1,
                  ),
                  child: Text(widget.item.label),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenterButton(_Palette p, bool selected) {
    return SizedBox(
      height: _DT.navHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: _DT.med,
            curve: Curves.easeOutBack,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_DT.radiusMd),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [p.accent, p.accent.withOpacity(0.75)]
                    : [
                        p.isDark
                            ? const Color(0xFF252830)
                            : const Color(0xFFE8ECF0),
                        p.isDark
                            ? const Color(0xFF1E2029)
                            : const Color(0xFFF0F3F7),
                      ],
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: p.accentGlow,
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: p.shadowLight,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(
              selected
                  ? widget.item.activeIcon
                  : widget.item.icon,
              size: 22,
              color: selected
                  ? (p.isDark ? const Color(0xFF0B0C10) : Colors.white)
                  : p.navUnselected,
            ),
          ),
          const SizedBox(height: _DT.space4),
          AnimatedDefaultTextStyle(
            duration: _DT.fast,
            style: TextStyle(
              fontSize: _DT.navLabelSize,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? p.navSelected : p.navUnselected,
              letterSpacing: 0.2,
            ),
            child: Text(widget.item.label),
          ),
        ],
      ),
    );
  }
}