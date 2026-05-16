import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../services/guest_notifications_service.dart';

class _DT {
  static Color accent(bool d) => d ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
  static Color accentSoft(bool d) =>
      d ? const Color(0xFF5CE1B0).withValues(alpha: 0.14) : const Color(0xFF00A878).withValues(alpha: 0.10);
  static Color accentGlow(bool d) =>
      d ? const Color(0xFF5CE1B0).withValues(alpha: 0.30) : const Color(0xFF00A878).withValues(alpha: 0.22);

  static const Color danger = Color(0xFFEF4444);
  static Color dangerSoft(bool d) =>
      d ? const Color(0xFFEF4444).withValues(alpha: 0.14) : const Color(0xFFEF4444).withValues(alpha: 0.10);

  static Color warm(bool d) => d ? const Color(0xFFFFB347) : const Color(0xFFF59E0B);

  static Color bgBase(bool d) => d ? const Color(0xFF0B0C10) : const Color(0xFFF5F6FA);

  static Color orb1(bool d) => d ? const Color(0xFF1A3A4A) : const Color(0xFFD6F5EC);
  static Color orb2(bool d) => d ? const Color(0xFF0D1F35) : const Color(0xFFE0EDFF);
  static Color orb3(bool d) => d ? const Color(0xFF221A3A) : const Color(0xFFF0E5FF);

  static Color glass(bool d) => d ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.80);
  static Color glassBorder(bool d) => d ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07);

  static Color text(bool d) => d ? const Color(0xFFF0F0F5) : const Color(0xFF0F1117);
  static Color muted(bool d) => d ? const Color(0xFF9095A8) : const Color(0xFF6B7280);

  static Color shadowCard(bool d) => d ? Colors.black.withValues(alpha: 0.40) : Colors.black.withValues(alpha: 0.06);
}

class GuestNotificationsScreen extends StatefulWidget {
  const GuestNotificationsScreen({super.key});

  @override
  State<GuestNotificationsScreen> createState() => _GuestNotificationsScreenState();
}

class _GuestNotificationsScreenState extends State<GuestNotificationsScreen>
    with TickerProviderStateMixin {
  late final GuestNotificationsService _service;
  Timer? _refreshTimer;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _unreadCount = 0;
  List<GuestNotificationItem> _notifications = const <GuestNotificationItem>[];

  late final AnimationController _heroCtrl;
  late final AnimationController _bgPulseCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _bgPulse;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _service = GuestNotificationsService(
      apiClient: ApiClient(secureStorage: SecureStorage()),
    );

    _heroCtrl = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
    );
    _heroFade = CurvedAnimation(
      parent: _heroCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
      CurvedAnimation(
        parent: _heroCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _bgPulseCtrl = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat(reverse: true);
    _bgPulse = CurvedAnimation(parent: _bgPulseCtrl, curve: Curves.easeInOut);

    _heroCtrl.forward();

    _loadNotifications();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _loadNotifications(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _heroCtrl.dispose();
    _bgPulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final results = await Future.wait<dynamic>([
        _service.listNotifications(perPage: 40),
        _service.unreadCount(),
      ]);

      if (!mounted) return;

      setState(() {
        _notifications = results[0] as List<GuestNotificationItem>;
        _unreadCount = results[1] as int;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      await _loadNotifications();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to mark notifications as read: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _openNotification(GuestNotificationItem item) async {
    if (!item.isRead) {
      try {
        await _service.markAsRead(item.id);
      } catch (_) {
        // Keep the UI responsive even if the API fails.
      }
    }

    await _loadNotifications(silent: true);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(item.body),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return _DT.danger;
      case 'normal':
        return _DT.accent(_isDark);
      default:
        return _DT.warm(_isDark);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: d
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _DT.bgBase(d),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
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
                        child: _isLoading
                            ? _buildShimmerList(d)
                            : _errorMessage != null
                                ? _buildErrorState(d)
                                : RefreshIndicator(
                                    onRefresh: _loadNotifications,
                                    color: _DT.accent(d),
                                    backgroundColor: _DT.glass(d),
                                    child: ListView(
                                      physics: const AlwaysScrollableScrollPhysics(
                                        parent: BouncingScrollPhysics(),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                                      children: [
                                        _buildSummaryCard(d),
                                        const SizedBox(height: 14),
                                        if (_notifications.isEmpty)
                                          _buildEmptyState(d)
                                        else
                                          ..._notifications.map((item) => _buildNotificationCard(item, d)),
                                      ],
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
    );
  }

  Widget _buildHeader(bool d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GlassIconButton(
            d: d,
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(Icons.arrow_back_rounded, color: _DT.text(d), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                    Text(
                      'NOVA PLUS',
                      style: TextStyle(
                        color: _DT.accent(d),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'الإشعارات',
                  style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: _DT.muted(d),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _GlassIconButton(
                d: d,
                onTap: _isLoading ? null : _markAllAsRead,
                child: Icon(Icons.done_all_rounded, color: _DT.text(d), size: 20),
              ),
              const SizedBox(width: 8),
              _GlassIconButton(
                d: d,
                onTap: _isRefreshing ? null : () => _loadNotifications(silent: true),
                child: _isRefreshing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _DT.accent(d),
                        ),
                      )
                    : Icon(Icons.refresh_rounded, color: _DT.text(d), size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool d) {
    return _GlassCard(
      d: d,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _DT.accentSoft(d),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _DT.accent(d).withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.notifications_active_outlined, color: _DT.accent(d), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inbox',
                  style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_unreadCount unread notification${_unreadCount == 1 ? '' : 's'}',
                  style: TextStyle(color: _DT.muted(d), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(GuestNotificationItem item, bool d) {
    final accentColor = _priorityColor(item.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openNotification(item),
        child: _GlassCard(
          d: d,
          borderColor: item.isRead ? null : accentColor.withValues(alpha: 0.42),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                  color: accentColor,
                  size: 22,
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
                            item.title,
                            style: TextStyle(
                              color: item.isRead ? _DT.muted(d) : _DT.text(d),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _DT.accent(d),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.body,
                      style: TextStyle(
                        color: _DT.muted(d),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(item.type.toUpperCase(), accentColor),
                        _pill(item.channel.toUpperCase(), _DT.warm(d)),
                        if (item.relatedType != null && item.relatedType!.isNotEmpty)
                          _pill(item.relatedType!.toUpperCase(), _DT.accent(d)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool d) {
    return _GlassCard(
      d: d,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: _DT.accent(d), size: 52),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                color: _DT.text(d),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'New broadcasts and chat alerts will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _DT.muted(d), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool d) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: _GlassCard(
          d: d,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _DT.dangerSoft(d),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _DT.danger.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.error_outline_rounded, color: _DT.danger, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load notifications',
                style: TextStyle(
                  color: _DT.text(d),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _DT.muted(d), fontSize: 13),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _loadNotifications,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: _DT.accent(d),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _DT.accentGlow(d),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: d ? const Color(0xFF0B0C10) : Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Retry',
                        style: TextStyle(
                          color: d ? const Color(0xFF0B0C10) : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList(bool d) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ShimmerCard(d: d),
      ),
    );
  }
}

class _AtmosphericBg extends StatelessWidget {
  const _AtmosphericBg({required this.d, required this.pulse});

  final bool d;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          return CustomPaint(
            painter: _BgPainter(d: d, t: pulse.value, size: size),
          );
        },
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  _BgPainter({required this.d, required this.t, required this.size});

  final bool d;
  final double t;
  final Size size;

  @override
  void paint(Canvas canvas, Size _) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _DT.bgBase(d),
    );

    final ease = Curves.easeInOut.transform(t);

    _drawOrb(
      canvas,
      center: Offset(size.width * 0.82 + ease * 12, size.height * 0.08 - ease * 10),
      radius: size.width * 0.52,
      color: _DT.orb1(d),
    );

    _drawOrb(
      canvas,
      center: Offset(size.width * 0.1 - ease * 10, size.height * 0.78 + ease * 8),
      radius: size.width * 0.45,
      color: _DT.orb2(d),
    );

    _drawOrb(
      canvas,
      center: Offset(size.width * 0.55 + ease * 6, size.height * 0.42 - ease * 6),
      radius: size.width * 0.3,
      color: _DT.orb3(d),
    );

    final gridPaint = Paint()
      ..color = d ? Colors.white.withValues(alpha: 0.025) : Colors.black.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.src;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BgPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.d != d;
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.d,
    required this.child,
    this.onTap,
  });

  final bool d;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _DT.glass(d),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _DT.glassBorder(d)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.d, required this.child, this.borderColor});

  final bool d;
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _DT.glass(d),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor ?? _DT.glassBorder(d), width: 1),
            boxShadow: [
              BoxShadow(
                color: _DT.shadowCard(d),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.d});

  final bool d;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1300), vsync: this)
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final base = d ? const Color(0xFF1A1C23) : const Color(0xFFECEFF4);
    final high = d ? const Color(0xFF22252F) : const Color(0xFFF5F7FA);
    final block = d ? const Color(0xFF111318) : const Color(0xFFE0E5EC);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: [base, high, base],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: block,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 140,
                        decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        height: 10,
                        width: 170,
                        decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            height: 20,
                            width: 56,
                            decoration: BoxDecoration(
                              color: block,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 20,
                            width: 56,
                            decoration: BoxDecoration(
                              color: block,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
