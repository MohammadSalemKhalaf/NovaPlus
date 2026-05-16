import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/end_user_profile_entity.dart';
import '../../domain/services/profile_service.dart';

class _DT {
  static Color accent(bool d) => d ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
  static Color accentSoft(bool d) =>
      d ? const Color(0xFF5CE1B0).withValues(alpha: 0.14) : const Color(0xFF00A878).withValues(alpha: 0.10);
  static Color accentGlow(bool d) =>
      d ? const Color(0xFF5CE1B0).withValues(alpha: 0.30) : const Color(0xFF00A878).withValues(alpha: 0.22);

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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
  });

  final EndUserProfileEntity profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  late final ProfileService _profileService;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();

  bool _isSaving = false;
  bool _showPassword = false;

  late final AnimationController _heroCtrl;
  late final AnimationController _bgPulseCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _bgPulse;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();

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

    final apiClient = ApiClient(secureStorage: SecureStorage());
    final repository = ProfileRepositoryImpl(apiClient: apiClient);
    _profileService = ProfileService(repository: repository);

    _nameController = TextEditingController(text: widget.profile.name);
    _emailController = TextEditingController(text: widget.profile.email);
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _bgPulseCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    final authState = context.read<AuthState>();

    final name = _nameController.text.trim();
    final password = _passwordController.text;

    if (password.isNotEmpty && password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{};

    final initialName = widget.profile.name.trim();
    if (name.isNotEmpty && name != initialName) {
      payload['name'] = name;
    }

    if (password.trim().isNotEmpty) {
      payload['password'] = password.trim();
    }

    if (payload.isEmpty) {
      _showInfo('No changes to save');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _profileService.updateProfile(payload);

      if (!mounted) return;

      if (payload['name'] is String) {
        await authState.setAuthenticated(
          role: authState.role ?? 'end_user',
          name: payload['name'] as String,
          email: authState.email,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Profile updated successfully')),
              ],
            ),
            backgroundColor: const Color(0xFF1F7A4D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

      Navigator.pop<bool>(context, true);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFFB00020),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _showInfo(String message) {
    final d = _isDark;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: d ? const Color(0xFF2A2A41) : const Color(0xFF5D6576),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(d),
                        const SizedBox(height: 16),
                        _buildAvatar(d),
                        const SizedBox(height: 16),
                        _buildFormCard(d),
                        const SizedBox(height: 16),
                        _buildSaveButton(d),
                        const SizedBox(height: 10),
                        _buildCancelButton(d),
                      ],
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

  Widget _buildHeader(bool d) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GlassIconButton(
          d: d,
          onTap: () => Navigator.pop(context),
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
                'تعديل الملف',
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
                'Edit Profile',
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
        _GlassIconButton(
          d: d,
          onTap: () {},
          child: Icon(Icons.edit_rounded, color: _DT.text(d), size: 20),
        ),
      ],
    );
  }

  Widget _buildAvatar(bool d) {
    final avatarText = widget.profile.name.trim().isEmpty
        ? '?'
        : widget.profile.name.trim().characters.first.toUpperCase();

    return Center(
      child: Container(
        width: 100,
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _DT.accentSoft(d),
          shape: BoxShape.circle,
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
            fontSize: 36,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(bool d) {
    return _GlassCard(
      d: d,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Full Name',
            style: TextStyle(
              color: _DT.muted(d),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _inputField(
            d: d,
            controller: _nameController,
            hint: 'Enter your full name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 18),
          Text(
            'Email Address',
            style: TextStyle(
              color: _DT.muted(d),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _inputField(
            d: d,
            controller: _emailController,
            hint: '',
            icon: Icons.email_outlined,
            readOnly: true,
            enabled: false,
          ),
          const SizedBox(height: 18),
          Text(
            'New Password',
            style: TextStyle(
              color: _DT.muted(d),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _inputField(
            d: d,
            controller: _passwordController,
            hint: 'Enter new password (optional)',
            icon: Icons.lock_outline_rounded,
            obscureText: !_showPassword,
            suffix: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: _DT.muted(d),
                size: 20,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _DT.accentSoft(d),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: _DT.accent(d)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Leave password empty to keep current password',
                    style: TextStyle(
                      color: _DT.muted(d),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required bool d,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    bool enabled = true,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscureText,
      style: TextStyle(
        color: enabled ? _DT.text(d) : _DT.muted(d),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _DT.muted(d), fontSize: 14),
        prefixIcon: Icon(icon, color: _DT.accent(d), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: d ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _DT.glassBorder(d)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _DT.glassBorder(d)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _DT.accent(d)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _DT.glassBorder(d)),
        ),
      ),
    );
  }

  Widget _buildSaveButton(bool d) {
    return GestureDetector(
      onTap: _isSaving ? null : _saveChanges,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: _DT.accent(d),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _DT.accentGlow(d),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: d ? const Color(0xFF0B0C10) : Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: d ? const Color(0xFF0B0C10) : Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Save Changes',
                      style: TextStyle(
                        color: d ? const Color(0xFF0B0C10) : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCancelButton(bool d) {
    return GestureDetector(
      onTap: _isSaving ? null : () => Navigator.pop(context),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: _DT.glass(d),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _DT.glassBorder(d), width: 1),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.close_rounded, color: _DT.muted(d), size: 20),
              const SizedBox(width: 10),
              Text(
                'Cancel',
                style: TextStyle(
                  color: _DT.muted(d),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
  const _BgPainter({required this.d, required this.t, required this.size});

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
