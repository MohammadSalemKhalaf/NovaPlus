import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────
//  Design Tokens  (same palette as AgentsTab for consistency)
// ─────────────────────────────────────────────────────────────
abstract final class _C {
  static const bg0        = Color(0xFF09090F);
  static const bg1        = Color(0xFF0F0F1A);
  static const bg2        = Color(0xFF141424);
  static const bg3        = Color(0xFF1C1C30);
  static const surface    = Color(0xFF1A1A2E);

  static const accent     = Color(0xFF6C63FF);
  static const accentSoft = Color(0xFF8B85FF);
  static const accentGlow = Color(0x336C63FF);
  static const accentDim  = Color(0x1A6C63FF);

  static const green      = Color(0xFF22C55E);
  static const greenDim   = Color(0x2022C55E);
  static const greenText  = Color(0xFF4ADE80);
  static const greenBorder= Color(0x4022C55E);

  static const amber      = Color(0xFFF59E0B);
  static const amberDim   = Color(0x20F59E0B);
  static const amberBorder= Color(0x40F59E0B);
  static const amberText  = Color(0xFFFCD34D);

  static const blue       = Color(0xFF3B82F6);
  static const blueDim    = Color(0x203B82F6);
  static const blueBorder = Color(0x403B82F6);
  static const blueText   = Color(0xFF93C5FD);

  static const textPrimary   = Color(0xFFF1F0FF);
  static const textSecondary = Color(0xFF9B99CC);
  static const textMuted     = Color(0xFF5C5A80);

  static const border        = Color(0xFF252540);
  static const borderSubtle  = Color(0xFF1C1C35);
}

abstract final class _R {
  static const card  = 22.0;
  static const btn   = 14.0;
  static const inner = 12.0;
  static const chip  = 999.0;
}

// ─────────────────────────────────────────────────────────────
//  Main Widget
// ─────────────────────────────────────────────────────────────
class AdminOwnerOnboardingTab extends StatelessWidget {
  const AdminOwnerOnboardingTab({
    super.key,
    required this.onOnboardOwner,
    required this.onCreateActivationCode,
    required this.onRedeemTenantOwner,
    required this.latestCode,
    required this.onCopyLatestCode,
  });

  final VoidCallback  onOnboardOwner;
  final VoidCallback  onCreateActivationCode;
  final VoidCallback  onRedeemTenantOwner;
  final String?       latestCode;
  final VoidCallback  onCopyLatestCode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        // ── Page header ──────────────────────────────────────
        _PageHeader(),

        const SizedBox(height: 20),

        // ── Action cards grid ────────────────────────────────
        _ActionGrid(
          onOnboardOwner:        onOnboardOwner,
          onCreateActivationCode: onCreateActivationCode,
          onRedeemTenantOwner:   onRedeemTenantOwner,
        ),

        // ── Latest code banner ───────────────────────────────
        if (latestCode != null && latestCode!.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ActivationCodeCard(
            code:   latestCode!,
            onCopy: onCopyLatestCode,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Page Header
// ─────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x406C63FF),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.how_to_reg_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owner Onboarding',
              style: TextStyle(
                color: _C.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Manage tenant owner lifecycle actions',
              style: TextStyle(color: _C.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Action Grid  –  3 individual styled cards
// ─────────────────────────────────────────────────────────────
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onOnboardOwner,
    required this.onCreateActivationCode,
    required this.onRedeemTenantOwner,
  });

  final VoidCallback onOnboardOwner;
  final VoidCallback onCreateActivationCode;
  final VoidCallback onRedeemTenantOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionCard(
          icon:        Icons.person_add_alt_1_rounded,
          title:       'Onboard Owner',
          description: 'Register and provision a new tenant owner account with full backend flow.',
          label:       'Start Onboarding',
          iconColor:   _C.accentSoft,
          iconBg:      _C.accentDim,
          btnColor:    _C.accent,
          btnGlow:     _C.accentGlow,
          onPressed:   onOnboardOwner,
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon:        Icons.key_rounded,
          title:       'Create Activation Code',
          description: 'Generate a new one-time activation code for a tenant owner invite.',
          label:       'Generate Code',
          iconColor:   _C.amberText,
          iconBg:      _C.amberDim,
          btnColor:    _C.amber,
          btnGlow:     _C.amberBorder,
          onPressed:   onCreateActivationCode,
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon:        Icons.lock_open_rounded,
          title:       'Redeem Tenant Owner',
          description: 'Redeem an existing activation code and complete owner registration.',
          label:       'Redeem Now',
          iconColor:   _C.blueText,
          iconBg:      _C.blueDim,
          btnColor:    _C.blue,
          btnGlow:     _C.blueBorder,
          onPressed:   onRedeemTenantOwner,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Single Action Card
// ─────────────────────────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.btnColor,
    required this.btnGlow,
    required this.onPressed,
  });

  final IconData   icon;
  final String     title;
  final String     description;
  final String     label;
  final Color      iconColor;
  final Color      iconBg;
  final Color      btnColor;
  final Color      btnGlow;
  final VoidCallback onPressed;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:  _hovering ? const Color(0xFF1E1E34) : _C.surface,
          borderRadius: BorderRadius.circular(_R.card),
          border: Border.all(
            color: _hovering
                ? widget.btnColor.withOpacity(0.35)
                : _C.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering
                  ? widget.btnGlow.withOpacity(0.25)
                  : const Color(0x10000000),
              blurRadius: _hovering ? 24 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: widget.iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        color: _C.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // CTA button
              _GlowButton(
                label:    widget.label,
                color:    widget.btnColor,
                glowColor: widget.btnGlow,
                onPressed: widget.onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Glow Button
// ─────────────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  const _GlowButton({
    required this.label,
    required this.color,
    required this.glowColor,
    required this.onPressed,
  });

  final String     label;
  final Color      color;
  final Color      glowColor;
  final VoidCallback onPressed;

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withOpacity(0.75)
              : widget.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(_R.btn),
          border: Border.all(color: widget.color.withOpacity(0.5)),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.glowColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _pressed ? Colors.white : widget.color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Activation Code Card
// ─────────────────────────────────────────────────────────────
class _ActivationCodeCard extends StatefulWidget {
  const _ActivationCodeCard({required this.code, required this.onCopy});

  final String       code;
  final VoidCallback onCopy;

  @override
  State<_ActivationCodeCard> createState() => _ActivationCodeCardState();
}

class _ActivationCodeCardState extends State<_ActivationCodeCard>
    with SingleTickerProviderStateMixin {
  bool _copied = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    widget.onCopy();
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(_R.card),
        border: Border.all(color: _C.greenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1822C55E),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              color: _C.greenDim,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_R.card),
              ),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.greenText.withOpacity(
                        0.5 + 0.5 * _pulse.value,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.green.withOpacity(0.4 * _pulse.value),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Latest Activation Code',
                  style: TextStyle(
                    color: _C.greenText,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: -0.1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.greenDim,
                    borderRadius: BorderRadius.circular(_R.chip),
                    border: Border.all(color: _C.greenBorder),
                  ),
                  child: const Text(
                    'Ready to use',
                    style: TextStyle(
                      color: _C.greenText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Code row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _C.bg1,
                borderRadius: BorderRadius.circular(_R.inner),
                border: Border.all(color: _C.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tag_rounded,
                    size: 15,
                    color: _C.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.code,
                      style: const TextStyle(
                        color:      _C.textPrimary,
                        fontFamily: 'monospace',
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CopyButton(
                    copied:    _copied,
                    onPressed: _handleCopy,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Copy Button  (animated feedback)
// ─────────────────────────────────────────────────────────────
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.onPressed});

  final bool             copied;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:  copied ? _C.greenDim : _C.accentDim,
          borderRadius: BorderRadius.circular(_R.inner),
          border: Border.all(
            color: copied ? _C.greenBorder : _C.accent.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              copied ? Icons.check_rounded : Icons.copy_rounded,
              size:  14,
              color: copied ? _C.greenText : _C.accentSoft,
            ),
            const SizedBox(width: 5),
            Text(
              copied ? 'Copied!' : 'Copy',
              style: TextStyle(
                color: copied ? _C.greenText : _C.accentSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}