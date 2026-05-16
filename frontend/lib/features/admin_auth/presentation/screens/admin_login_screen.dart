import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../admin/presentation/screens/admin_dashboard_screen.dart';
import '../../data/datasources/admin_auth_remote_data_source.dart';
import '../../data/repositories/admin_auth_repository_impl.dart';
import '../../domain/entities/admin_login_credentials_entity.dart';
import '../../domain/repositories/admin_auth_repository.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AdminAuthRepository _adminAuthRepository;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    final secureStorage = SecureStorage();
    final apiClient = ApiClient(secureStorage: secureStorage);
    final remoteDataSource = AdminAuthRemoteDataSource(apiClient: apiClient);
    _adminAuthRepository = AdminAuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      secureStorage: secureStorage,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _adminAuthRepository.login(
        AdminLoginCredentialsEntity(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      );

      _showSnackBar(
        message: 'Admin login successful',
        backgroundColor: const Color(0xFF1F7A4D),
      );

      if (!mounted) {
        return;
      }

      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const AdminDashboardScreen(),
        ),
      );
    } on DioException catch (error) {
      final responseData = error.response?.data;
      String errorMessage = error.message ?? 'Admin login failed';

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];
        if (message is String && message.isNotEmpty) {
          errorMessage = message;
        }
      }

      _showSnackBar(
        message: errorMessage,
        backgroundColor: const Color(0xFFB00020),
      );
    } catch (error) {
      _showSnackBar(
        message: error.toString().replaceFirst('Exception: ', ''),
        backgroundColor: const Color(0xFFB00020),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
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
    return Scaffold(
      backgroundColor: const Color(0xFF080812),
      body: Stack(
        children: [
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
                    const Color(0xFF5B3FE8).withValues(alpha: 0.18),
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
                    const Color(0xFF1A6EFF).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10101E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF242438), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B3FE8).withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                          const BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Admin Sign in',
                            style: TextStyle(
                              color: Color(0xFFF0F0FF),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Access admin controls',
                            style: TextStyle(
                              color: Color(0xFF6B6B88),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _label('Email address'),
                          const SizedBox(height: 8),
                          _input(
                            controller: _emailController,
                            hintText: 'admin@novaplus.test',
                            keyboardType: TextInputType.emailAddress,
                            prefix: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: 20),
                          _label('Password'),
                          const SizedBox(height: 8),
                          _input(
                            controller: _passwordController,
                            hintText: '••••••••',
                            obscureText: _obscurePassword,
                            prefix: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 20,
                                color: const Color(0xFF6B6B88),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _onLoginPressed,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6A4EFF), Color(0xFF2E7BFF)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign in as Admin',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFC9C9DD),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hintText,
    required IconData prefix,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        color: Color(0xFFF0F0FF),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF5A5A78),
          fontSize: 14,
        ),
        prefixIcon: Icon(prefix, color: const Color(0xFF7A7AA0), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF151528),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF25253D), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6A4EFF), width: 1.2),
        ),
      ),
    );
  }
}
