import 'package:flutter/material.dart';

import '../../controllers/owner_profile_controller.dart';
import '../../theme/owner_theme.dart';

class OwnerProfileTab extends StatefulWidget {
  const OwnerProfileTab({
    super.key,
    required this.controller,
    required this.onLogout,
    required this.onEditProfile,
    required this.isDarkMode,
    required this.onThemeModeChanged,
  });

  final OwnerProfileController controller;
  final Future<void> Function() onLogout;
  final VoidCallback onEditProfile;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeModeChanged;

  @override
  State<OwnerProfileTab> createState() => _OwnerProfileTabState();
}

class _OwnerProfileTabState extends State<OwnerProfileTab> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return _LoadingState(palette: palette);
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PageHeader(palette: palette),
                    const SizedBox(height: 20),
                    _ProfileHeaderCard(
                      palette: palette,
                      ownerName: widget.controller.ownerName,
                      ownerEmail: widget.controller.ownerEmail,
                    ),
                    const SizedBox(height: 24),
                    _AppearanceCard(
                      palette: palette,
                      isDarkMode: widget.isDarkMode,
                      onChanged: widget.onThemeModeChanged,
                    ),
                    const SizedBox(height: 24),
                    _StatsCard(
                      palette: palette,
                      tenantName: widget.controller.tenantName,
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(
                      palette: palette,
                      title: 'Account Settings',
                    ),
                    const SizedBox(height: 16),
                    _ProfileAction(
                      palette: palette,
                      icon: Icons.edit_rounded,
                      title: 'Edit Profile',
                      subtitle: 'Update your name and WhatsApp',
                      color: palette.primary,
                      onTap: widget.onEditProfile,
                    ),
                    const SizedBox(height: 12),
                    _ProfileAction(
                      palette: palette,
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      subtitle: 'Sign out from your account',
                      color: palette.error,
                      onTap: widget.onLogout,
                    ),
                    const SizedBox(height: 20),
                    _VersionInfo(palette: palette),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// Loading State
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.palette});

  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF7C5CFF),
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(
              color: Color(0xFF9A9AA8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Page Header
// ============================================================================

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.palette});

  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile',
          style: TextStyle(
            color: palette.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage your account information',
          style: TextStyle(
            color: palette.onSurfaceMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Section Title
// ============================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.palette});

  final String title;
  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
            style: TextStyle(
            color: palette.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Profile Header Card
// ============================================================================

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.palette,
    required this.ownerName,
    required this.ownerEmail,
  });

  final OwnerPalette palette;
  final String ownerName;
  final String ownerEmail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [palette.surfaceElevated, palette.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar Section
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C5CFF), Color(0xFF5B3CE6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF1E1E2A),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              ownerName,
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            // Email
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 14,
                  color: Color(0xFF9A9AA8),
                ),
                const SizedBox(width: 6),
                Text(
                  ownerEmail,
                  style: TextStyle(
                    color: palette.onSurfaceMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: Color(0xFF7C5CFF),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Store Owner',
                    style: TextStyle(
                      color: palette.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Stats Card
// ============================================================================

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.tenantName, required this.palette});

  final String tenantName;
  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store_rounded,
                size: 20,
                color: Color(0xFF7C5CFF),
              ),
              SizedBox(width: 8),
              Text(
                'Store Information',
                style: TextStyle(
                  color: palette.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    size: 20,
                    color: Color(0xFF7C5CFF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Store',
                        style: TextStyle(
                          color: palette.onSurfaceMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tenantName.isEmpty ? 'No store assigned' : tenantName,
                        style: TextStyle(
                          color: palette.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.successSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      color: palette.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
}

// ============================================================================
// Profile Action
// ============================================================================

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final OwnerPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color == palette.error 
                            ? color 
                            : palette.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.onSurfaceMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.onSurfaceSoft,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Version Info
// ============================================================================

class _VersionInfo extends StatelessWidget {
  const _VersionInfo({required this.palette});

  final OwnerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Divider(
            color: Color(0xFF2A2A35),
            thickness: 0.5,
          ),
          const SizedBox(height: 16),
          Text(
            'Version 2.0.0',
            style: TextStyle(
              color: palette.onSurfaceSoft,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2024 NovaPlus',
            style: TextStyle(
              color: palette.onSurfaceSoft,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard({
    required this.palette,
    required this.isDarkMode,
    required this.onChanged,
  });

  final OwnerPalette palette;
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: palette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    color: palette.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDarkMode ? 'Dark mode' : 'Light mode',
                  style: TextStyle(
                    color: palette.onSurfaceMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDarkMode,
            onChanged: onChanged,
            activeThumbColor: palette.primary,
          ),
        ],
      ),
    );
  }
}