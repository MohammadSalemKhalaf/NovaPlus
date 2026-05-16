import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/storage/secure_storage.dart';
import '../cubit_or_bloc/sales_agent_cubit.dart';

class SalesAgentRedeemSubscriptionScreen extends StatefulWidget {
  const SalesAgentRedeemSubscriptionScreen({
    super.key,
    this.initialTenantId,
  });

  final int? initialTenantId;

  @override
  State<SalesAgentRedeemSubscriptionScreen> createState() =>
      _SalesAgentRedeemSubscriptionScreenState();
}

class _SalesAgentRedeemSubscriptionScreenState
    extends State<SalesAgentRedeemSubscriptionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  int? _resolvedTenantId;
  bool _prefillStarted = false;
  bool _autoCreatingCode = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  double _safeOpacity(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialTenantId != null && widget.initialTenantId! > 0) {
      _resolvedTenantId = widget.initialTenantId;
      SecureStorage().saveTenantId(widget.initialTenantId!.toString());
    }

    _prefillFields();
    
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefillStarted) {
      _prefillFields();
    }
  }

  Future<void> _prefillFields() async {
    if (_prefillStarted) {
      return;
    }
    _prefillStarted = true;

    final cubit = context.read<SalesAgentCubit>();

    if (_resolvedTenantId == null) {
      _resolvedTenantId = await _getResolvedTenantId();
    }

    var existingCode = cubit.state.lastActivationCode?.code.trim() ?? '';

    if (existingCode.isEmpty) {
      final latest = await cubit.loadLatestActiveCode();
      existingCode = latest?.code.trim() ?? '';
    }

    if (existingCode.isNotEmpty) {
      _code.text = existingCode;
    } else if (_resolvedTenantId != null) {
      await _autoCreateCodeIfNeeded(cubit);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _autoCreateCodeIfNeeded(SalesAgentCubit cubit) async {
    if (_autoCreatingCode) {
      return;
    }

    if (_code.text.trim().isNotEmpty) {
      return;
    }

    _autoCreatingCode = true;
    if (mounted) {
      setState(() {});
    }

    await cubit.createActivationCode(durationMonths: 1);

    final generated = cubit.state.lastActivationCode?.code.trim() ?? '';
    if (generated.isNotEmpty) {
      _code.text = generated;
    }

    _autoCreatingCode = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<int?> _getResolvedTenantId() async {
    // Tenant must come from secure storage
    try {
      final tenantIdStr = await SecureStorage().getTenantId();
      if (tenantIdStr != null && tenantIdStr.isNotEmpty) {
        return int.tryParse(tenantIdStr);
      }
    } catch (_) {}

    return null;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_resolvedTenantId == null) {
      _show('Please select a store first', isError: true);
      return;
    }

    final tenantId = _resolvedTenantId!;
    print('FINAL TENANT USED: $tenantId');

    final cubit = context.read<SalesAgentCubit>();
    await cubit.redeemSubscription(
      code: _code.text.trim(),
      tenantId: tenantId,
    );

    if (!mounted) {
      return;
    }

    final state = cubit.state;
    if (state.errorMessage != null) {
      _handleErrorMessage(state.errorMessage!);
      return;
    }

    final status = state.lastRedeemResult?.status;

    final raw = state.lastRedeemResult?.raw;
    final responseTenantId = raw != null && raw['tenant_id'] is num
        ? (raw['tenant_id'] as num).toInt()
        : null;

    if (responseTenantId != null && responseTenantId != tenantId) {
      _show(
        'Activation completed for tenant $responseTenantId, not tenant $tenantId. Please retry from the correct store card.',
        isError: true,
      );
      return;
    }

    _show(
      status == null || status.isEmpty
          ? 'Subscription activated successfully'
          : 'Subscription activated: $status',
    );

    Navigator.of(context).pop(true);
  }

  void _handleErrorMessage(String errorMessage) {
    // Check if it's a slug duplication error (422)
    if (errorMessage.contains('slug') || errorMessage.contains('already exists')) {
      _show('Store name already exists, please choose another name', isError: true);
    } else {
      _show(errorMessage, isError: true);
    }
  }

  void _show(String message, {bool isError = false}) {
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
        final isReady = _resolvedTenantId != null && _code.text.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFF0A0A1A),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFFF2F2FF),
            title: const Text(
              'Activate Subscription',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0A1A).withOpacity(0.95),
                    const Color(0xFF0A0A1A).withOpacity(0),
                  ],
                ),
              ),
            ),
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
                        opacity: _safeOpacity(value),
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
                                    Icons.redeem_rounded,
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
                                        'Redeem Subscription',
                                        style: TextStyle(
                                          color: Color(0xFFF2F2FF),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Enter activation code to activate subscription',
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

                  if (_autoCreatingCode) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7B61FF).withOpacity(0.15),
                            const Color(0xFF3A8DFF).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF7B61FF).withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Generating activation code automatically...',
                              style: TextStyle(
                                color: Color(0xFFD6D6FF),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status Banner
                  if (isReady) ...[
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: _safeOpacity(value),
                          child: Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1F7A4D).withOpacity(0.15),
                                    const Color(0xFF1F7A4D).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF1F7A4D).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F7A4D).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: Color(0xFF1F7A4D),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Ready to activate subscription for tenant $_resolvedTenantId',
                                      style: const TextStyle(
                                        color: Color(0xFF1F7A4D),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ] else if (_resolvedTenantId == null) ...[
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: _safeOpacity(value),
                          child: Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFB00020).withOpacity(0.15),
                                    const Color(0xFFB00020).withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFB00020).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB00020).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: Color(0xFFB00020),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Please select a store first',
                                      style: TextStyle(
                                        color: Color(0xFFB00020),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Code Section
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: _safeOpacity(value),
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Container(
                            padding: const EdgeInsets.all(20),
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
                                      child: const Icon(
                                        Icons.key_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Activation Details',
                                      style: TextStyle(
                                        color: Color(0xFFF2F2FF),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _StyledRedeemField(
                                  controller: _code,
                                  label: 'Activation Code',
                                  icon: Icons.code_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B61FF), Color(0xFF3A8DFF)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7B61FF).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: (state.submitting || !isReady || _autoCreatingCode)
                                ? null
                                : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: state.submitting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Activating...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Activate Subscription',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
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
}

class _StyledRedeemField extends StatelessWidget {
  const _StyledRedeemField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        color: Color(0xFFF2F2FF),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFABABCA)),
        prefixIcon: Icon(icon, color: const Color(0xFF7B61FF), size: 22),
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
        return null;
      },
    );
  }
}