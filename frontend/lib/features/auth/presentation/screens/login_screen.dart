import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../cart/data/device_service.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../../favorites/data/favorites_api.dart';
import '../../../favorites/data/favorites_repository.dart';
import '../../../favorites/presentation/favorites_cubit.dart';
import '../../../guest/presentation/screens/guest_shell_screen.dart';
import '../../../sales_agent/presentation/screens/sales_agent_shell_screen.dart';
import '../../../stores/presentation/screens/owner_shell_screen.dart';
import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/login_credentials_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.loginType = LoginType.admin,
  });

  final LoginType loginType;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AuthRepository _authRepository;
  late final DeviceService _deviceService;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isEndUserLogin => widget.loginType == LoginType.endUser;

  @override
  void initState() {
    super.initState();

    final secureStorage = SecureStorage();
    final apiClient = ApiClient(secureStorage: secureStorage);
    final remoteDataSource = AuthRemoteDataSource(apiClient: apiClient);
    _deviceService = DeviceService(secureStorage: secureStorage);

    _authRepository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      secureStorage: secureStorage,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  Future<void> _onLoginPressed() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final authState = context.read<AuthState>();
      final cartState = context.read<CartState>();

      final session = await _authRepository.login(
        LoginCredentialsEntity(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          loginType: widget.loginType,
          deviceId: await _deviceService.getDeviceId(),
        ),
      );

      _showSnackBar(
        message: 'Login successful',
        backgroundColor: const Color(0xFF1F7A4D),
      );

      if (!mounted) {
        return;
      }

      final resolvedRole = session.role.trim().toLowerCase();
      final isAdmin = resolvedRole == 'admin';
      final isOwner = resolvedRole == 'owner';
      final isSalesAgent = resolvedRole == 'sales_agent';
      final isEndUser = resolvedRole == 'end_user';

      late final String appContext;
      if (isAdmin) {
        appContext = 'admin';
      } else if (isOwner) {
        appContext = 'owner';
      } else if (isSalesAgent) {
        appContext = 'sales_agent';
      } else if (isEndUser) {
        appContext = 'end_user';
      } else {
        await authState.setUnauthenticated();
        if (!mounted) {
          return;
        }
        _showSnackBar(
          message: 'Unknown role: $resolvedRole',
          backgroundColor: const Color(0xFFB00020),
        );
        return;
      }

      await authState.setAuthenticated(
        role: appContext,
        name: session.ownerName,
        email: session.ownerEmail,
      );

      if (appContext == 'end_user') {
        final storage = SecureStorage();
        final apiClient = ApiClient(secureStorage: storage);
        final favoritesApi = FavoritesApi(apiClient: apiClient);
        final favoritesRepository = FavoritesRepository(api: favoritesApi);
        final favoritesCubit = FavoritesCubit(
          repository: favoritesRepository,
          authState: authState,
        );
        await favoritesCubit.loadFavorites();
      }

      if (appContext == 'end_user') {
        if (!mounted) {
          return;
        }

        await cartState.fetchCart();
      }

      if (!mounted) {
        return;
      }

      await Navigator.pushAndRemoveUntil<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) {
            if (appContext == 'end_user') {
              return const GuestShellScreen();
            }
            if (appContext == 'owner') {
              return const OwnerShellScreen();
            }
            if (appContext == 'admin') {
              return const AdminDashboardScreen();
            }
            if (appContext == 'sales_agent') {
              return const SalesAgentShellScreen();
            }
            return const GuestShellScreen();
          },
        ),
        (_) => false,
      );
    } on DioException catch (_) {
      _showSnackBar(
        message: 'Invalid credentials',
        backgroundColor: const Color(0xFFB00020),
      );
    } catch (_) {
      _showSnackBar(
        message: 'Invalid credentials',
        backgroundColor: const Color(0xFFB00020),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isEndUser = _isEndUserLogin;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isLightStyle = isEndUser && !isDarkMode;
    final bgColor = isLightStyle ? const Color(0xFFF5F6FA) : const Color(0xFF080812);
    final cardColor = isLightStyle
        ? Colors.white.withValues(alpha: 0.82)
        : const Color(0xFF10101E);
    final cardBorder = isLightStyle ? const Color(0x2200A878) : const Color(0xFF242438);
    final titleColor = isLightStyle ? const Color(0xFF0F1117) : const Color(0xFFF0F0FF);
    final subtitleColor = isLightStyle ? const Color(0xFF6B7280) : const Color(0xFF6B6B88);

    final overlayStyle = isDarkMode
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isEndUser ? const Color(0xFF00A878) : const Color(0xFF5B3FE8))
                        .withValues(alpha: isLightStyle ? 0.16 : 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isEndUser ? const Color(0xFF10B981) : const Color(0xFF1A6EFF))
                        .withValues(alpha: isLightStyle ? 0.14 : 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo ──
                        _NovaPlusLogo(
                          isEndUser: isEndUser,
                          isLightStyle: isLightStyle,
                        ),
                        const SizedBox(height: 36),

                        // ── Card ──
                        Container(
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cardBorder,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isEndUser
                                        ? const Color(0xFF00A878)
                                        : const Color(0xFF5B3FE8))
                                    .withValues(alpha: isLightStyle ? 0.10 : 0.12),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isLightStyle ? 0.07 : 0.40),
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header
                              Text(
                                isEndUser ? 'أهلا بعودتك' : 'Welcome back',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEndUser
                                    ? 'سجّل الدخول للمتابعة والاستفادة من كل المزايا'
                                    : 'Sign in to your owner account',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Divider line
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      isLightStyle ? const Color(0x2200A878) : const Color(0xFF2E2E4A),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Email Field
                              _buildLabel(isEndUser ? 'البريد الإلكتروني' : 'Email address'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: _fieldIcon(Icons.alternate_email_rounded, isLightStyle),
                                isLightStyle: isLightStyle,
                              ),
                              const SizedBox(height: 20),

                              // Password Field
                              _buildLabel(isEndUser ? 'كلمة المرور' : 'Password'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _passwordController,
                                hintText: '••••••••',
                                obscureText: _obscurePassword,
                                prefixIcon: _fieldIcon(Icons.lock_outline_rounded, isLightStyle),
                                isLightStyle: isLightStyle,
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: isLightStyle
                                        ? const Color(0xFF6B7280)
                                        : const Color(0xFF55556E),
                                    size: 20,
                                  ),
                                ),
                              ),

                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    isEndUser ? 'نسيت كلمة المرور؟' : 'Forgot password?',
                                    style: TextStyle(
                                      color: isEndUser
                                          ? const Color(0xFF00A878)
                                          : const Color(0xFF7B61FF),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Login Button
                              SizedBox(
                                height: 52,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isEndUser
                                          ? const [Color(0xFF00A878), Color(0xFF22C55E)]
                                          : const [Color(0xFF6A4EFF), Color(0xFF2E7BFF)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isEndUser
                                                ? const Color(0xFF00A878)
                                                : const Color(0xFF5B3FE8))
                                            .withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _onLoginPressed,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      disabledBackgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                isEndUser ? 'تسجيل الدخول' : 'Sign in',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: isLightStyle
                                          ? const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)]
                                          : const [Color(0xFF121827), Color(0xFF0C1020)],
                                    ),
                                    border: Border.all(
                                      color: isLightStyle
                                          ? const Color(0x3300A878)
                                          : const Color(0xFF2A2A44),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isLightStyle ? 0.04 : 0.18,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: OutlinedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            Navigator.pushReplacement<void, void>(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (_) => const GuestShellScreen(),
                                              ),
                                            );
                                          },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: isLightStyle
                                          ? const Color(0xFF0B6E57)
                                          : const Color(0xFFF0F0FF),
                                      disabledForegroundColor: isLightStyle
                                          ? const Color(0xFF0B6E57).withValues(alpha: 0.5)
                                          : const Color(0xFFF0F0FF).withValues(alpha: 0.5),
                                      side: BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: 19,
                                          color: isLightStyle
                                              ? const Color(0xFF0B6E57)
                                              : const Color(0xFFF0F0FF),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEndUser ? 'الدخول كضيف' : 'Continue as Guest',
                                          style: TextStyle(
                                            color: isLightStyle
                                                ? const Color(0xFF0B6E57)
                                                : const Color(0xFFF0F0FF),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
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

                        const SizedBox(height: 24),
                        // Footer
                        Text(
                          '© 2025 NovaPLus — All rights reserved',
                          style: TextStyle(
                            color: isLightStyle
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF3A3A55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final isLightStyle = _isEndUserLogin && Theme.of(context).brightness != Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        color: isLightStyle ? const Color(0xFF6B7280) : const Color(0xFFAAAAAC),
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _fieldIcon(IconData icon, bool isLightStyle) {
    return Icon(
      icon,
      color: isLightStyle ? const Color(0xFF6B7280) : const Color(0xFF55556E),
      size: 20,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? prefixIcon,
    Widget? suffixIcon,
    required bool isLightStyle,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        color: isLightStyle ? const Color(0xFF0F1117) : const Color(0xFFF0F0FF),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isLightStyle ? const Color(0xFF9CA3AF) : const Color(0xFF3A3A55),
          fontSize: 15,
        ),
        prefixIcon: prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: prefixIcon,
              )
            : null,
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffixIcon,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: isLightStyle ? const Color(0xFFF8FAFC) : const Color(0xFF0C0C1A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLightStyle ? const Color(0x3300A878) : const Color(0xFF222238),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLightStyle ? const Color(0x3300A878) : const Color(0xFF222238),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLightStyle ? const Color(0xFF00A878) : const Color(0xFF6A4EFF),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NovaPLus Logo Widget
// ─────────────────────────────────────────────
class _NovaPlusLogo extends StatefulWidget {
  const _NovaPlusLogo({required this.isEndUser, required this.isLightStyle});

  final bool isEndUser;
  final bool isLightStyle;

  @override
  State<_NovaPlusLogo> createState() => _NovaPlusLogoState();
}

class _NovaPlusLogoState extends State<_NovaPlusLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _float = CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEndUser = widget.isEndUser;
    final isLightStyle = widget.isLightStyle;
    final wordBase = isLightStyle ? const Color(0xFF0F1117) : const Color(0xFFF0F0FF);
    final wordAccent = isEndUser ? const Color(0xFF00A878) : const Color(0xFF7B61FF);

    return AnimatedBuilder(
      animation: _float,
      builder: (_, __) {
        final t = _float.value;
        final y = (t - 0.5) * 8;
        final glowAlpha = 0.18 + (t * 0.22);

        return Transform.translate(
          offset: Offset(0, y),
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  // Purple background matching the real logo
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF047857),
                      Color(0xFF059669),
                      Color(0xFF065F46),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isEndUser ? const Color(0xFF00A878) : const Color(0xFF5B3FE8))
                          .withValues(alpha: glowAlpha),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const _NovaNMarkWidget(),
              ),
              const SizedBox(height: 14),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Nova ',
                      style: TextStyle(
                        color: wordBase,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    TextSpan(
                      text: 'Plus',
                      style: TextStyle(
                        color: wordAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEndUser ? 'End User Login' : 'Owner Portal',
                style: TextStyle(
                  color: isLightStyle ? const Color(0xFF64748B) : const Color(0xFF44445A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Nova N Mark
// ─────────────────────────────────────────────
class _NovaNMarkWidget extends StatelessWidget {
  const _NovaNMarkWidget();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 12,
          top: 10,
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: 14,
          bottom: 14,
          child: Container(
            width: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFB8F7DC), Color(0xFF45D6AA)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 38,
          top: 14,
          child: Transform.rotate(
            angle: -0.82,
            alignment: Alignment.center,
            child: Container(
              width: 22,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFA7F3D0), Color(0xFF34D399)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 14,
          bottom: 14,
          child: Container(
            width: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7DE6C0), Color(0xFF10B981)],
              ),
            ),
          ),
        ),
        Positioned(
          right: 7,
          top: 7,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4ADE80), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.add,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.12),
                  Colors.black.withValues(alpha: 0.03),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
