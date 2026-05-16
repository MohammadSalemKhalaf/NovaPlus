import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/state/theme_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../auth/domain/entities/login_credentials_entity.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../favorites/presentation/favorites_cubit.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/end_user_profile_entity.dart';
import '../../domain/services/profile_service.dart';
import '../state/profile_state.dart';
import '../services/guest_notifications_service.dart';
import 'edit_profile_screen.dart';
import 'guest_notifications_screen.dart';
import 'guest_shell_screen.dart';

class _DT {
  static Color accent(bool d) => d ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
  static Color accentSoft(bool d) =>
      d ? const Color(0xFF5CE1B0).withValues(alpha: 0.13) : const Color(0xFF00A878).withValues(alpha: 0.10);
  static Color accentGlow(bool d) =>
      d ? const Color(0xFF5CE1B0).withValues(alpha: 0.30) : const Color(0xFF00A878).withValues(alpha: 0.22);

  static Color warm(bool d) => d ? const Color(0xFFFFB347) : const Color(0xFFF59E0B);
  static Color warmSoft(bool d) =>
      d ? const Color(0xFFFFB347).withValues(alpha: 0.13) : const Color(0xFFF59E0B).withValues(alpha: 0.10);

  static const Color danger = Color(0xFFEF4444);

  static Color bgBase(bool d) => d ? const Color(0xFF0B0C10) : const Color(0xFFF5F6FA);
  static Color bgCard(bool d) => d ? const Color(0xFF1A1C23) : const Color(0xFFFFFFFF);

  static Color orb1(bool d) => d ? const Color(0xFF1A3A4A) : const Color(0xFFD6F5EC);
  static Color orb2(bool d) => d ? const Color(0xFF0D1F35) : const Color(0xFFE0EDFF);
  static Color orb3(bool d) => d ? const Color(0xFF221A3A) : const Color(0xFFF0E5FF);

  static Color glass(bool d) => d ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.80);
  static Color glassBorder(bool d) => d ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07);

  static Color text(bool d) => d ? const Color(0xFFF0F0F5) : const Color(0xFF0F1117);
  static Color muted(bool d) => d ? const Color(0xFF9095A8) : const Color(0xFF6B7280);
  static Color hint(bool d) => d ? const Color(0xFF555B70) : const Color(0xFFB0B7C3);
  static Color border(bool d) => d ? const Color(0xFF222530) : const Color(0xFFE8ECF2);

  static Color shadowCard(bool d) => d ? Colors.black.withValues(alpha: 0.40) : Colors.black.withValues(alpha: 0.06);
}

Color _statusColor(String status, bool d) {
  final value = status.toLowerCase();
  if (value.contains('active')) return _DT.accent(d);
  if (value.contains('pending')) return _DT.warm(d);
  if (value.contains('blocked') || value.contains('inactive')) return _DT.danger;
  return _DT.warm(d);
}

Color _statusBg(String status, bool d) {
  final value = status.toLowerCase();
  if (value.contains('active')) return _DT.accentSoft(d);
  if (value.contains('pending')) return _DT.warmSoft(d);
  if (value.contains('blocked') || value.contains('inactive')) {
    return _DT.danger.withValues(alpha: d ? 0.13 : 0.09);
  }
  return _DT.warmSoft(d);
}

class GuestProfileScreen extends StatefulWidget {
  const GuestProfileScreen({super.key});

  @override
  State<GuestProfileScreen> createState() => _GuestProfileScreenState();
}

class _GuestProfileScreenState extends State<GuestProfileScreen>
    with TickerProviderStateMixin {
  late final ProfileService _profileService;
  late final GuestNotificationsService _notificationsService;

  Timer? _notificationsTimer;
  ProfileState _profileState = const ProfileState(isLoading: false);
  int _unreadNotifications = 0;

  late AnimationController _heroCtrl;
  late AnimationController _bgPulseCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late Animation<double> _bgPulse;

  @override
  void initState() {
    super.initState();
    _initAnimations();

    final apiClient = ApiClient(secureStorage: SecureStorage());
    final repository = ProfileRepositoryImpl(apiClient: apiClient);
    _profileService = ProfileService(repository: repository);
    _notificationsService = GuestNotificationsService(apiClient: apiClient);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthState>();
      if (authState.isAuthenticated) {
        _loadProfile();
        _loadUnreadNotifications();
      }
    });

    _notificationsTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _loadUnreadNotifications(silent: true);
    });
  }

  void _initAnimations() {
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
  }

  @override
  void dispose() {
    _notificationsTimer?.cancel();
    _heroCtrl.dispose();
    _bgPulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadNotifications({bool silent = false}) async {
    try {
      final count = await _notificationsService.unreadCount();
      if (!mounted) return;
      setState(() => _unreadNotifications = count);
    } catch (error) {
      if (!mounted || silent) return;
      debugPrint('Failed to load unread notifications: $error');
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const GuestNotificationsScreen()),
    );

    if (mounted) {
      await _loadUnreadNotifications();
    }
  }

  Future<void> _goToLogin(BuildContext context) async {
    await Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(loginType: LoginType.endUser),
      ),
      (route) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    final authState = context.read<AuthState>();
    final cartState = context.read<CartState>();
    final favoritesCubit = context.read<FavoritesCubit>();
    final storage = SecureStorage();
    await ApiClient(secureStorage: storage).resetSessionHeaders();

    await storage.clearAuthData();
    cartState.clearLocalCart();
    favoritesCubit.clear();
    setState(() => _profileState = const ProfileState(isLoading: false));
    await authState.setUnauthenticated();

    if (!context.mounted) return;

    await Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const GuestShellScreen()),
      (route) => false,
    );
  }

  Future<void> _loadProfile() async {
    setState(() => _profileState = ProfileState.loading());

    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;
      setState(() => _profileState = ProfileState.success(profile));
    } catch (error) {
      if (!mounted) return;

      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() => _profileState = ProfileState.error(message));

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $message'),
            backgroundColor: Theme.of(context).colorScheme.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
    }
  }

  Future<void> _openEditProfile(EndUserProfileEntity profile) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => EditProfileScreen(profile: profile)),
    );

    if (updated == true && mounted) {
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = context.watch<ThemeState>().isDarkMode;
    final authState = context.watch<AuthState>();
    final isGuestMode = !authState.isAuthenticated || authState.isGuest;

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
                      _buildHeader(d, isGuestMode),
                      Expanded(
                        child: isGuestMode
                            ? _buildGuestModeBody(d)
                            : _buildAuthenticatedBody(d),
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

  Widget _buildHeader(bool d, bool isGuestMode) {
    final isDarkMode = d;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                  'الملف الشخصي',
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
                  'My Profile',
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
                onTap: () => context.read<ThemeState>().toggleTheme(),
                child: Icon(
                  isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: _DT.text(d),
                  size: 20,
                ),
              ),
              if (!isGuestMode) ...[
                const SizedBox(width: 8),
                _GlassIconButton(
                  d: d,
                  onTap: _openNotifications,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.notifications_none_rounded, color: _DT.text(d), size: 20),
                      if (_unreadNotifications > 0)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _DT.danger,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuestModeBody(bool d) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: _GlassCard(
        d: d,
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _DT.accentSoft(d),
                shape: BoxShape.circle,
                border: Border.all(color: _DT.accent(d).withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.person_outline_rounded, size: 46, color: _DT.accent(d)),
            ),
            const SizedBox(height: 20),
            Text(
              'Guest Mode',
              style: TextStyle(
                color: _DT.text(d),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are browsing as a guest.\nSign in to unlock full features.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _DT.muted(d), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            _ActionButton(
              d: d,
              icon: Icons.login_rounded,
              label: 'Login / Register',
              onTap: () => _goToLogin(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedBody(bool d) {
    if (_profileState.isLoading) {
      return _buildLoadingSkeleton(d);
    }

    if (_profileState.hasError) {
      return _buildErrorState(d);
    }

    final profile = _profileState.profile;
    if (profile == null) {
      return const SizedBox.shrink();
    }

    return _buildProfileContent(profile, d);
  }

  Widget _buildProfileContent(EndUserProfileEntity profile, bool d) {
    final avatarText =
        profile.name.trim().isEmpty ? '?' : profile.name.trim().characters.first.toUpperCase();
    final statusColor = _statusColor(profile.status, d);
    final statusBg = _statusBg(profile.status, d);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        children: [
          _GlassCard(
            d: d,
            child: Column(
              children: [
                Container(
                  width: 102,
                  height: 102,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _DT.accentSoft(d),
                    border: Border.all(color: _DT.accent(d).withValues(alpha: 0.35), width: 1.1),
                    boxShadow: [
                      BoxShadow(
                        color: _DT.accentGlow(d),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    avatarText,
                    style: TextStyle(
                      color: _DT.accent(d),
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.email,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _DT.muted(d), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: statusColor.withValues(alpha: 0.33), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        profile.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _GlassCard(
            d: d,
            child: Column(
              children: [
                _InfoTile(d: d, icon: Icons.badge_outlined, label: 'Role', value: profile.primaryRole),
                _InfoTile(
                  d: d,
                  icon: Icons.verified_rounded,
                  label: 'Status',
                  value: profile.status,
                  valueColor: statusColor,
                ),
                _InfoTile(d: d, icon: Icons.mail_outline_rounded, label: 'Email', value: profile.email),
                _InfoTile(
                  d: d,
                  icon: Icons.perm_identity_rounded,
                  label: 'User ID',
                  value: profile.id.toString(),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            d: d,
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => _openEditProfile(profile),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            d: d,
            icon: Icons.logout_rounded,
            label: 'Logout',
            danger: true,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(bool d) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        children: [
          _GlassCard(
            d: d,
            child: const Column(
              children: [
                _ShimmerBlock(width: 90, height: 90, circular: true),
                SizedBox(height: 16),
                _ShimmerBlock(width: 170, height: 18),
                SizedBox(height: 8),
                _ShimmerBlock(width: 220, height: 12),
                SizedBox(height: 12),
                _ShimmerBlock(width: 90, height: 24),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _GlassCard(
            d: d,
            child: const Column(
              children: [
                _ShimmerBlock(width: double.infinity, height: 46),
                SizedBox(height: 10),
                _ShimmerBlock(width: double.infinity, height: 46),
                SizedBox(height: 10),
                _ShimmerBlock(width: double.infinity, height: 46),
                SizedBox(height: 10),
                _ShimmerBlock(width: double.infinity, height: 46),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _ShimmerBlock(width: double.infinity, height: 52),
          const SizedBox(height: 10),
          const _ShimmerBlock(width: double.infinity, height: 52),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool d) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: _GlassCard(
        d: d,
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: _DT.danger.withValues(alpha: d ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _DT.danger.withValues(alpha: 0.35)),
              ),
              child: const Icon(Icons.error_outline_rounded, color: _DT.danger, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Unable to load profile',
              style: TextStyle(
                color: _DT.text(d),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _profileState.error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: _DT.muted(d), fontSize: 13.5),
            ),
            const SizedBox(height: 22),
            _ActionButton(
              d: d,
              icon: Icons.refresh_rounded,
              label: 'Retry',
              onTap: _loadProfile,
            ),
          ],
        ),
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
  const _GlassIconButton({required this.d, required this.onTap, required this.child});

  final bool d;
  final VoidCallback onTap;
  final Widget child;

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
  const _GlassCard({required this.d, required this.child});

  final bool d;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _DT.glass(d),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _DT.glassBorder(d), width: 1),
            boxShadow: [
              BoxShadow(
                color: _DT.shadowCard(d),
                blurRadius: 18,
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.d,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.showDivider = true,
  });

  final bool d;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: _DT.border(d))) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _DT.accentSoft(d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: _DT.accent(d)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _DT.hint(d),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? _DT.text(d),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.d,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final bool d;
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? _DT.danger : (d ? const Color(0xFF0B0C10) : Colors.white);
    final bg = danger ? _DT.danger.withValues(alpha: d ? 0.15 : 0.11) : _DT.accent(d);
    final borderColor = danger ? _DT.danger.withValues(alpha: 0.35) : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: danger
              ? null
              : [
                  BoxShadow(
                    color: _DT.accentGlow(d),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 19),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatefulWidget {
  const _ShimmerBlock({
    required this.width,
    required this.height,
    this.circular = false,
  });

  final double width;
  final double height;
  final bool circular;

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
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
    final d = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.circular ? 999 : 14),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: [
                _DT.bgCard(d),
                _DT.bgCard(d).withValues(alpha: d ? 0.86 : 0.72),
                _DT.bgCard(d),
              ],
            ),
          ),
        );
      },
    );
  }
}
