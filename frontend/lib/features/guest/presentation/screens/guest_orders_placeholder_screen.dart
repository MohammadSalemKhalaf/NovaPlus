import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/domain/entities/login_credentials_entity.dart';
import '../../../auth/presentation/screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS — unified with GuestShellScreen / GuestStoresScreen
// ─────────────────────────────────────────────────────────────────────────────

class _DT {
  // Accent
  static Color accent(bool d)      => d ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
  static Color accentSoft(bool d)  => d ? const Color(0xFF5CE1B0).withOpacity(0.13) : const Color(0xFF00A878).withOpacity(0.10);
  static Color accentGlow(bool d)  => d ? const Color(0xFF5CE1B0).withOpacity(0.28) : const Color(0xFF00A878).withOpacity(0.20);

  // Warm accent (status / highlights)
  static Color warm(bool d)        => d ? const Color(0xFFFFB347) : const Color(0xFFF59E0B);
  static Color warmSoft(bool d)    => d ? const Color(0xFFFFB347).withOpacity(0.13) : const Color(0xFFF59E0B).withOpacity(0.10);

  // Danger
  static const danger              = Color(0xFFEF4444);
  static Color dangerSoft(bool d)  => const Color(0xFFEF4444).withOpacity(d ? 0.13 : 0.09);

  // Purple accent
  static const purple              = Color(0xFF8B5CF6);
  static Color purpleSoft(bool d)  => const Color(0xFF8B5CF6).withOpacity(d ? 0.13 : 0.09);

  // Backgrounds
  static Color bgBase(bool d)      => d ? const Color(0xFF0B0C10) : const Color(0xFFF5F6FA);
  static Color bgSurface(bool d)   => d ? const Color(0xFF141519) : const Color(0xFFFFFFFF);
  static Color bgCard(bool d)      => d ? const Color(0xFF1A1C23) : const Color(0xFFFFFFFF);
  static Color bgFloat(bool d)     => d ? const Color(0xFF1E2029) : const Color(0xFFFFFFFF);

  // Orbs
  static Color orb1(bool d)        => d ? const Color(0xFF1A3A4A) : const Color(0xFFD6F5EC);
  static Color orb2(bool d)        => d ? const Color(0xFF0D1F35) : const Color(0xFFE0EDFF);
  static Color orb3(bool d)        => d ? const Color(0xFF221A3A) : const Color(0xFFF0E5FF);

  // Glass
  static Color glass(bool d)       => d ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.80);
  static Color glassBorder(bool d) => d ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);

  // Text
  static Color text(bool d)        => d ? const Color(0xFFF0F0F5) : const Color(0xFF0F1117);
  static Color muted(bool d)       => d ? const Color(0xFF9095A8) : const Color(0xFF6B7280);
  static Color hint(bool d)        => d ? const Color(0xFF555B70) : const Color(0xFFB0B7C3);
  static Color border(bool d)      => d ? const Color(0xFF222530) : const Color(0xFFE8ECF2);

  // Shadow
  static Color shadowCard(bool d)  => d ? Colors.black.withOpacity(0.40) : Colors.black.withOpacity(0.06);
}

// Status helpers
Color _statusColor(String status, bool d) {
  final s = status.toLowerCase();
  if (s.contains('delivered') || s.contains('completed')) return _DT.accent(d);
  if (s.contains('processing') || s.contains('pending')) return _DT.warm(d);
  if (s.contains('cancelled') || s.contains('refunded')) return _DT.danger;
  return _DT.purple;
}

Color _statusBg(String status, bool d) {
  final s = status.toLowerCase();
  if (s.contains('delivered') || s.contains('completed')) return _DT.accentSoft(d);
  if (s.contains('processing') || s.contains('pending')) return _DT.warmSoft(d);
  if (s.contains('cancelled') || s.contains('refunded')) return _DT.dangerSoft(d);
  return _DT.purpleSoft(d);
}

String _formatDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) return '';
  try {
    final dt = DateTime.parse(dateString);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return '';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class GuestOrdersPlaceholderScreen extends StatefulWidget {
  const GuestOrdersPlaceholderScreen({super.key});

  @override
  State<GuestOrdersPlaceholderScreen> createState() =>
      _GuestOrdersPlaceholderScreenState();
}

class _GuestOrdersPlaceholderScreenState
    extends State<GuestOrdersPlaceholderScreen>
    with TickerProviderStateMixin {
  late final ApiClient _apiClient;
  late final SecureStorage _secureStorage;
  Future<List<dynamic>>? _ordersFuture;

  late AnimationController _heroCtrl;
  late AnimationController _bgPulseCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _bgPulse;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _secureStorage = SecureStorage();
    _apiClient = ApiClient(secureStorage: _secureStorage);

    _heroCtrl = AnimationController(
        duration: const Duration(milliseconds: 750), vsync: this);
    _heroFade = CurvedAnimation(
        parent: _heroCtrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut));
    _heroSlide = Tween<Offset>(
            begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _heroCtrl,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));

    _bgPulseCtrl = AnimationController(
        duration: const Duration(seconds: 7), vsync: this)
      ..repeat(reverse: true);
    _bgPulse =
        CurvedAnimation(parent: _bgPulseCtrl, curve: Curves.easeInOut);

    _heroCtrl.forward();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _bgPulseCtrl.dispose();
    super.dispose();
  }

  void _ensureOrdersLoaded(bool isAuthenticated) {
    if (!isAuthenticated) {
      _ordersFuture = null;
      return;
    }
    _ordersFuture ??= _fetchOrders();
  }

  Future<List<dynamic>> _fetchOrders() async {
    final localOrders = await _secureStorage.getLocalOrders();
    try {
      final response =
          await _apiClient.get<Map<String, dynamic>>('/enduser/orders');
      final data = response.data;
      if (data == null) return localOrders;
      final payload = data['data'];
      if (payload is List) {
        return payload.isNotEmpty ? payload : localOrders;
      }
      if (payload is Map && payload['orders'] is List) {
        final orders = payload['orders'] as List<dynamic>;
        return orders.isNotEmpty ? orders : localOrders;
      }
      return localOrders;
    } catch (_) {
      return localOrders;
    }
  }

  Future<void> _goToLogin(BuildContext ctx) async {
    await Navigator.pushAndRemoveUntil<void>(
      ctx,
      MaterialPageRoute<void>(
          builder: (_) =>
              const LoginScreen(loginType: LoginType.endUser)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _isDark;
    final authState = context.watch<AuthState>();
    _ensureOrdersLoaded(authState.isAuthenticated);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: d
          ? SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _DT.bgBase(d),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // ── Atmospheric bg
            _AtmosphericBg(d: d, pulse: _bgPulse),

            SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _heroFade,
                child: SlideTransition(
                  position: _heroSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(d),
                      Expanded(
                        child: authState.isAuthenticated
                            ? FutureBuilder<List<dynamic>>(
                                future: _ordersFuture,
                                builder: (ctx, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return _buildShimmerList(d);
                                  }
                                  final orders = snapshot.data ??
                                      const <dynamic>[];
                                  if (orders.isEmpty) {
                                    return _buildEmptyState(d);
                                  }
                                  return _buildOrdersList(orders, d);
                                },
                              )
                            : _buildUnauthState(d),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  AnimatedBuilder(
                    animation: _bgPulse,
                    builder: (_, __) => Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _DT.accent(d),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _DT.accentGlow(d),
                            blurRadius: 8 * _bgPulse.value,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('NOVA PLUS',
                      style: TextStyle(
                        color: _DT.accent(d),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.6,
                      )),
                ]),
                const SizedBox(height: 6),
                Text('الطلبات',
                    style: TextStyle(
                      color: _DT.text(d),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      height: 1.0,
                    )),
                const SizedBox(height: 3),
                Text('My Orders',
                    style: TextStyle(
                      color: _DT.muted(d),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    )),
              ],
            ),
          ),
          // Glass icon button
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _DT.glass(d),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _DT.glassBorder(d)),
                ),
                child: Icon(Icons.receipt_long_rounded,
                    color: _DT.text(d), size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Unauthenticated ───────────────────────────────────────────────────────

  Widget _buildUnauthState(bool d) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: _DT.accentSoft(d),
                border: Border.all(
                    color: _DT.accent(d).withOpacity(0.28), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _DT.accentGlow(d),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.lock_outline_rounded,
                  color: _DT.accent(d), size: 38),
            ),
            const SizedBox(height: 24),
            Text('تسجيل الدخول مطلوب',
                style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text('Login Required',
                style: TextStyle(
                    color: _DT.accent(d),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2)),
            const SizedBox(height: 12),
            Text(
              'سجّل دخولك لعرض سجل طلباتك ومتابعة حالتها',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _DT.muted(d), fontSize: 13.5, height: 1.6),
            ),
            const SizedBox(height: 32),
            _AccentButton(
              label: 'تسجيل الدخول',
              sublabel: 'Login / Register',
              icon: Icons.login_rounded,
              d: d,
              onTap: () => _goToLogin(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool d) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: _DT.accentSoft(d),
                border: Border.all(
                    color: _DT.accent(d).withOpacity(0.28), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: _DT.accentGlow(d), blurRadius: 28, spreadRadius: 2),
                ],
              ),
              child: Icon(Icons.inbox_rounded,
                  color: _DT.accent(d), size: 38),
            ),
            const SizedBox(height: 24),
            Text('لا توجد طلبات',
                style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text('No Orders Yet',
                style: TextStyle(
                    color: _DT.accent(d),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'ستظهر هنا جميع طلباتك بعد أول عملية شراء',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _DT.muted(d), fontSize: 13.5, height: 1.6),
            ),
            const SizedBox(height: 32),
            _AccentButton(
              label: 'تصفّح المتاجر',
              sublabel: 'Start Shopping',
              icon: Icons.storefront_rounded,
              d: d,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Orders List ───────────────────────────────────────────────────────────

  Widget _buildOrdersList(List<dynamic> orders, bool d) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        setState(() => _ordersFuture = _fetchOrders());
        await _ordersFuture;
      },
      color: _DT.accent(d),
      backgroundColor: _DT.bgSurface(d),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        itemCount: orders.length,
        itemBuilder: (ctx, i) {
          final order      = orders[i];
          final id         = order is Map ? (order['id']?.toString() ?? '#') : '#';
          final status     = order is Map ? (order['status']?.toString() ?? 'pending') : 'pending';
          final total      = order is Map ? (order['subtotal'] ?? order['total'] ?? 0) : 0;
          final itemsCount = order is Map ? (order['items_count'] ?? order['itemsCount'] ?? 0) : 0;
          final date       = _formatDate(order is Map ? order['created_at']?.toString() : null);
          final totalVal   = total is double ? total : double.tryParse(total.toString()) ?? 0;
          final itemsVal   = itemsCount is int ? itemsCount : int.tryParse(itemsCount.toString()) ?? 0;

          return _StaggerCard(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _OrderCard(
                id: id,
                status: status,
                total: totalVal,
                itemsCount: itemsVal,
                date: date,
                d: d,
                onViewDetails: () =>
                    _showOrderDetails(id, status, totalVal, itemsVal, date, d),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Shimmer ───────────────────────────────────────────────────────────────

  Widget _buildShimmerList(bool d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        children: List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ShimmerCard(delay: i * 100, d: d),
          ),
        ),
      ),
    );
  }

  // ── Bottom Sheet ──────────────────────────────────────────────────────────

  void _showOrderDetails(
      String id, String status, double total, int items, String date, bool d) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (ctx, scrollCtrl) {
            final sc = _statusColor(status, d);
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: _DT.bgFloat(d),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border(
                        top: BorderSide(
                            color: _DT.glassBorder(d), width: 0.8)),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _DT.border(d),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
                          children: [
                            // Sheet header
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _DT.accentSoft(d),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _DT.accent(d).withOpacity(0.28)),
                                ),
                                child: Icon(Icons.receipt_long_rounded,
                                    color: _DT.accent(d), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Order #$id',
                                        style: TextStyle(
                                            color: _DT.text(d),
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3)),
                                    if (date.isNotEmpty)
                                      Text(date,
                                          style: TextStyle(
                                              color: _DT.muted(d),
                                              fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(sheetCtx),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _DT.border(d),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close_rounded,
                                      color: _DT.muted(d), size: 18),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 24),
                            // Stats row
                            Row(children: [
                              Expanded(
                                  child: _StatPill(
                                icon: Icons.shopping_bag_rounded,
                                label: 'Items',
                                value: '$items',
                                color: _DT.purple,
                                softColor: _DT.purpleSoft(d),
                                d: d,
                              )),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _StatPill(
                                icon: Icons.payments_rounded,
                                label: 'Total',
                                value: '\$${total.toStringAsFixed(2)}',
                                color: _DT.accent(d),
                                softColor: _DT.accentSoft(d),
                                d: d,
                              )),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _StatPill(
                                icon: Icons.local_shipping_rounded,
                                label: 'Status',
                                value: status,
                                color: sc,
                                softColor: _statusBg(status, d),
                                d: d,
                              )),
                            ]),
                            const SizedBox(height: 20),
                            // Info card
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _DT.bgCard(d),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: _DT.border(d), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: _DT.shadowCard(d),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.info_outline_rounded,
                                        color: _DT.accent(d), size: 15),
                                    const SizedBox(width: 7),
                                    Text('Order Information',
                                        style: TextStyle(
                                            color: _DT.text(d),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5)),
                                  ]),
                                  const SizedBox(height: 12),
                                  Text(
                                    'This order contains $items item(s) with a total of \$${total.toStringAsFixed(2)}.',
                                    style: TextStyle(
                                        color: _DT.muted(d),
                                        fontSize: 13,
                                        height: 1.6),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Container(
                                      width: 3,
                                      height: 13,
                                      decoration: BoxDecoration(
                                        color: sc,
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(status.toUpperCase(),
                                        style: TextStyle(
                                            color: sc,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            letterSpacing: 0.8)),
                                  ]),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ORDER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    required this.id,
    required this.status,
    required this.total,
    required this.itemsCount,
    required this.date,
    required this.d,
    required this.onViewDetails,
  });
  final String id, status, date;
  final double total;
  final int itemsCount;
  final bool d;
  final VoidCallback onViewDetails;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 100), vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.974)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final sc = _statusColor(widget.status, d);
    final sbg = _statusBg(widget.status, d);

    return GestureDetector(
      onTapDown: (_) {
        _ctrl.forward();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _ctrl.reverse();
        setState(() => _pressed = false);
        widget.onViewDetails();
      },
      onTapCancel: () {
        _ctrl.reverse();
        setState(() => _pressed = false);
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _DT.bgCard(d),
            border: Border.all(
              color: _pressed
                  ? _DT.accent(d).withOpacity(0.45)
                  : _DT.border(d),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _DT.shadowCard(d),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              if (_pressed)
                BoxShadow(
                  color: _DT.accentGlow(d),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: icon + id + status badge
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _DT.accentSoft(d),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: _DT.accent(d).withOpacity(0.25)),
                    ),
                    child: Icon(Icons.receipt_long_rounded,
                        color: _DT.accent(d), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order #${widget.id}',
                            style: TextStyle(
                                color: _DT.text(d),
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                letterSpacing: -0.2)),
                        if (widget.date.isNotEmpty)
                          Text(widget.date,
                              style: TextStyle(
                                  color: _DT.hint(d), fontSize: 11.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: sbg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sc.withOpacity(0.32), width: 0.8),
                    ),
                    child: Text(
                      widget.status.toUpperCase(),
                      style: TextStyle(
                          color: sc,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          letterSpacing: 0.6),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // ── Divider
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _DT.border(d),
                      _DT.border(d).withOpacity(0),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Row 2: meta stats
                Row(children: [
                  _MiniStat(
                    icon: Icons.shopping_bag_outlined,
                    value: '${widget.itemsCount}',
                    label: 'Items',
                    color: _DT.purple,
                    d: d,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.payments_outlined,
                    value: '\$${widget.total.toStringAsFixed(2)}',
                    label: 'Total',
                    color: _DT.accent(d),
                    d: d,
                  ),
                  const Spacer(),
                  // View details button
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _DT.accentSoft(d),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _DT.accent(d).withOpacity(0.28)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_outlined,
                            color: _DT.accent(d), size: 14),
                        const SizedBox(width: 5),
                        Text('Details',
                            style: TextStyle(
                                color: _DT.accent(d),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MINI STAT (inside card)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.d,
  });
  final IconData icon;
  final String value, label;
  final Color color;
  final bool d;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(
                    color: _DT.hint(d),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAT PILL (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.softColor,
    required this.d,
  });
  final IconData icon;
  final String label, value;
  final Color color, softColor;
  final bool d;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.28), width: 0.8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 7),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: _DT.muted(d), fontSize: 10.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACCENT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _AccentButton extends StatelessWidget {
  const _AccentButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.d,
    required this.onTap,
  });
  final String label, sublabel;
  final IconData icon;
  final bool d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
        decoration: BoxDecoration(
          color: _DT.accent(d),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _DT.accentGlow(d),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: d ? const Color(0xFF0B0C10) : Colors.white,
                size: 19),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: d
                            ? const Color(0xFF0B0C10)
                            : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: 0.1)),
                Text(sublabel,
                    style: TextStyle(
                        color: d
                            ? const Color(0xFF0B0C10).withOpacity(0.6)
                            : Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ATMOSPHERIC BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────

class _AtmosphericBg extends StatelessWidget {
  final bool d;
  final Animation<double> pulse;

  const _AtmosphericBg({required this.d, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) => CustomPaint(
          painter: _BgPainter(d: d, t: pulse.value, size: size),
        ),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final bool d;
  final double t;
  final Size size;
  _BgPainter({required this.d, required this.t, required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _DT.bgBase(d));

    final e = Curves.easeInOut.transform(t);
    _drawOrb(canvas,
        center: Offset(size.width * 0.82 + e * 12, size.height * 0.08 - e * 10),
        radius: size.width * 0.52,
        color: _DT.orb1(d));
    _drawOrb(canvas,
        center: Offset(size.width * 0.1 - e * 10, size.height * 0.78 + e * 8),
        radius: size.width * 0.45,
        color: _DT.orb2(d));
    _drawOrb(canvas,
        center: Offset(size.width * 0.55 + e * 6, size.height * 0.42 - e * 6),
        radius: size.width * 0.30,
        color: _DT.orb3(d));

    final dotPaint = Paint()
      ..color = (d ? Colors.white : Colors.black).withOpacity(0.028);
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }
  }

  void _drawOrb(Canvas canvas,
      {required Offset center, required double radius, required Color color}) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t || old.d != d;
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAGGER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StaggerCard extends StatefulWidget {
  const _StaggerCard({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggerCard> createState() => _StaggerCardState();
}

class _StaggerCardState extends State<_StaggerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: Duration(milliseconds: 480 + widget.index * 50),
        vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 70),
        () => mounted ? _ctrl.forward() : null);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.delay, required this.d});
  final int delay;
  final bool d;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () => mounted ? _ctrl.repeat() : null);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final base  = d ? const Color(0xFF1A1C23) : const Color(0xFFECEDF1);
    final high  = d ? const Color(0xFF22252F) : const Color(0xFFF5F6FA);
    final block = d ? const Color(0xFF111318) : const Color(0xFFE2E4EA);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0.3),
            end: Alignment(_anim.value + 1, 0.3),
            colors: [base, high, base],
          ),
        ),
        child: Row(children: [
          Container(
            margin: const EdgeInsets.all(14),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12), color: block),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 13,
                      width: 110,
                      decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 9),
                  Container(
                      height: 10,
                      width: 72,
                      decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 64,
            height: 24,
            decoration: BoxDecoration(
                color: block, borderRadius: BorderRadius.circular(10)),
          ),
        ]),
      ),
    );
  }
}