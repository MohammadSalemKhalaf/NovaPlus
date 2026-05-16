import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/auth_state.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/domain/entities/login_credentials_entity.dart';

class GuestBannerWidget extends StatelessWidget {
  const GuestBannerWidget({super.key});

  Future<void> _goToLogin(BuildContext context) async {
    await Navigator.pushAndRemoveUntil<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(loginType: LoginType.endUser),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGuest = context.select<AuthState, bool>(
      (state) => state.isGuest,
    );

    if (!isGuest) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15251F) : const Color(0xFFF3FCF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2D4B41) : const Color(0xFFA9E9D3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            color: isDark ? const Color(0xFF8DE1C0) : const Color(0xFF0F7A5B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You are browsing as Guest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE8FFF6) : const Color(0xFF084C3A),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Login or register to access full features',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFA6CEC0) : const Color(0xFF4E7A6D),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _goToLogin(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: isDark ? const Color(0xFF10B981) : const Color(0xFF00A878),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Login / Register',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
