import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cubit_or_bloc/sales_agent_cubit.dart';

class SalesAgentOnboardOwnerScreen extends StatefulWidget {
  const SalesAgentOnboardOwnerScreen({super.key});

  @override
  State<SalesAgentOnboardOwnerScreen> createState() =>
      _SalesAgentOnboardOwnerScreenState();
}

class _SalesAgentOnboardOwnerScreenState
    extends State<SalesAgentOnboardOwnerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _ownerName = TextEditingController();
  final _ownerEmail = TextEditingController();
  final _password = TextEditingController();
  final _tenantName = TextEditingController();
  final _tenantSlug = TextEditingController();
  final _tenantWhatsapp = TextEditingController();

  String _businessMode = 'product';
  String _activationChannel = 'email';
  int? _businessTypeId;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _ownerName.dispose();
    _ownerEmail.dispose();
    _password.dispose();
    _tenantName.dispose();
    _tenantSlug.dispose();
    _tenantWhatsapp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cubit = context.read<SalesAgentCubit>();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_businessTypeId == null) {
      _showMessage('Business type is required', isError: true);
      return;
    }

    await cubit.onboardOwner(
      ownerName: _ownerName.text.trim(),
      ownerEmail: _ownerEmail.text.trim(),
      password: _password.text.trim(),
      tenantName: _tenantName.text.trim(),
      tenantSlug: _tenantSlug.text.trim(),
      businessMode: _businessMode,
      activationChannel: _activationChannel,
      businessTypeId: _businessTypeId!,
      tenantWhatsappNumber: _tenantWhatsapp.text.trim(),
    );

    if (!mounted) {
      return;
    }

    final state = cubit.state;
    if (state.errorMessage != null) {
      _showMessage(state.errorMessage!, isError: true);
      return;
    }

    final result = state.lastOnboarding;
    if (result != null) {
      _showMessage(
        'Owner created. owner_user_id=${result.ownerUserId}, tenant_id=${result.tenantId}',
      );
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? const Color(0xFFB00020) : const Color(0xFF1F7A4D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SalesAgentCubit>(
      builder: (context, cubit, _) {
        final state = cubit.state;
        final businessTypes = state.businessTypes;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFFF2F2FF),
            title: const Text(
              'Onboard Owner',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            elevation: 0,
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  // Animated Header
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF7B61FF).withOpacity(0.15),
                                  const Color(0xFF3A8DFF).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF7B61FF).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF7B61FF), Color(0xFF3A8DFF)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Owner Registration',
                                        style: TextStyle(
                                          color: Color(0xFFF2F2FF),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Fill in the details to onboard a new store owner',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 12,
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
                  ),
                  
                  // Owner Information Section
                  _StyledSection(
                    title: 'Owner Information',
                    child: Column(
                      children: [
                        _StyledTextField(
                          controller: _ownerName,
                          label: 'Owner Name',
                        ),
                        const SizedBox(height: 12),
                        _StyledTextField(
                          controller: _ownerEmail,
                          label: 'Owner Email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _StyledTextField(
                          controller: _password,
                          label: 'Password',
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Store Information Section
                  _StyledSection(
                    title: 'Store Information',
                    child: Column(
                      children: [
                        _StyledTextField(
                          controller: _tenantName,
                          label: 'Tenant Name',
                        ),
                        const SizedBox(height: 12),
                        _StyledTextField(
                          controller: _tenantSlug,
                          label: 'Tenant Slug',
                        ),
                        const SizedBox(height: 12),
                        _StyledTextField(
                          controller: _tenantWhatsapp,
                          label: 'Tenant WhatsApp Number',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _businessTypeId,
                          dropdownColor: const Color(0xFF1A1A3A),
                          iconEnabledColor: const Color(0xFF7B61FF),
                          decoration: _inputDecoration('Business Type'),
                          items: businessTypes
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.id,
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(color: Color(0xFFF2F2FF)),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: state.submitting
                              ? null
                              : (value) => setState(() => _businessTypeId = value),
                          validator: (value) => value == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _businessMode,
                          dropdownColor: const Color(0xFF1A1A3A),
                          iconEnabledColor: const Color(0xFF7B61FF),
                          decoration: _inputDecoration('Business Mode'),
                          items: const [
                            DropdownMenuItem(value: 'product', child: Text('product')),
                            DropdownMenuItem(value: 'service', child: Text('service')),
                          ],
                          onChanged: state.submitting
                              ? null
                              : (value) => setState(() => _businessMode = value ?? 'product'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _activationChannel,
                          dropdownColor: const Color(0xFF1A1A3A),
                          iconEnabledColor: const Color(0xFF7B61FF),
                          decoration: _inputDecoration('Activation Channel'),
                          items: const [
                            DropdownMenuItem(value: 'email', child: Text('email')),
                            DropdownMenuItem(value: 'whatsapp', child: Text('whatsapp')),
                          ],
                          onChanged: state.submitting
                              ? null
                              : (value) =>
                                  setState(() => _activationChannel = value ?? 'email'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B61FF), Color(0xFF3A8DFF)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B61FF).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: state.submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: state.submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Submit Onboarding',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFABABCA)),
      prefixIcon: Icon(Icons.arrow_drop_down_circle_outlined, color: const Color(0xFF7B61FF), size: 20),
      filled: true,
      fillColor: const Color(0xFF15152A).withOpacity(0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 1.5),
      ),
    );
  }
}

class _StyledSection extends StatelessWidget {
  const _StyledSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1A3A).withOpacity(0.6),
                    const Color(0xFF121225).withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF7B61FF).withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B61FF), Color(0xFF3A8DFF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          title == 'Owner Information' 
                              ? Icons.person_outline_rounded 
                              : Icons.store_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFFF2F2FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  child!,
                ],
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFFF2F2FF)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFABABCA)),
        prefixIcon: Icon(
          label == 'Owner Name' ? Icons.badge_outlined :
          label == 'Owner Email' ? Icons.email_outlined :
          label == 'Password' ? Icons.lock_outline_rounded :
          label == 'Tenant Name' ? Icons.business_outlined :
          label == 'Tenant Slug' ? Icons.link_outlined :
          Icons.chat_outlined,
          color: const Color(0xFF7B61FF),
          size: 20,
        ),
        filled: true,
        fillColor: const Color(0xFF15152A).withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7B61FF), width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        if (label == 'Owner Email' && !value.contains('@')) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }
}