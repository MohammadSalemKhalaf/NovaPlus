import 'dart:ui';

import 'package:flutter/material.dart';

class EndUserOnboardingScreen extends StatefulWidget {
  const EndUserOnboardingScreen({
    super.key,
    required this.onStartNow,
    required this.onSkip,
  });

  final Future<void> Function() onStartNow;
  final Future<void> Function() onSkip;

  @override
  State<EndUserOnboardingScreen> createState() => _EndUserOnboardingScreenState();
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.orbColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color orbColor;
}

class _EndUserOnboardingScreenState extends State<EndUserOnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _index = 0;
  bool _isFinishing = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  static const List<_OnboardingPageData> _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      title: 'اكتشف أفضل المتاجر',
      subtitle: 'تصفّح المتاجر والعروض القريبة منك بسرعة وبواجهة سهلة.',
      icon: Icons.storefront_rounded,
      orbColor: Color(0xFF00A878),
    ),
    _OnboardingPageData(
      title: 'اطلب خلال دقائق',
      subtitle: 'اختَر المنتجات، أضفها للسلة، وتابع طلباتك لحظة بلحظة.',
      icon: Icons.local_mall_rounded,
      orbColor: Color(0xFF5C9DFF),
    ),
    _OnboardingPageData(
      title: 'QR و إشعارات فورية',
      subtitle: 'ادخل المتجر مباشرة عبر QR وابقَ على اطلاع بأحدث التحديثات.',
      icon: Icons.qr_code_scanner_rounded,
      orbColor: Color(0xFF8B5CF6),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await widget.onStartNow();
  }

  Future<void> _skip() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    await widget.onSkip();
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final t = _pulse.value;
                return CustomPaint(
                  painter: _OnboardingBgPainter(pulse: t),
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: _isFinishing ? null : _skip,
                        child: const Text(
                          'تخطي',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Column(
                          children: [
                            Expanded(
                              child: _HeroCard(page: page, pulse: _pulse),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF00A878).withValues(alpha: 0.12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    page.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F1117),
                                      height: 1.08,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    page.subtitle,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      color: Color(0xFF4B5563),
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                  child: Row(
                    children: [
                      Row(
                        children: List<Widget>.generate(_pages.length, (dotIndex) {
                          final selected = dotIndex == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.only(right: 8),
                            width: selected ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF00A878)
                                  : const Color(0xFFC8CEDA),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                      const Spacer(),
                      _PrimaryCtaButton(
                        label: isLast ? 'ابدأ الآن' : 'التالي',
                        loading: _isFinishing,
                        onTap: _next,
                      ),
                    ],
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.page, required this.pulse});

  final _OnboardingPageData page;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 18,
                left: 18,
                child: _FloatingBadge(
                  pulse: pulse,
                  icon: Icons.bolt_rounded,
                  color: page.orbColor,
                ),
              ),
              Positioned(
                top: 18,
                right: 18,
                child: _FloatingBadge(
                  pulse: pulse,
                  icon: Icons.local_offer_rounded,
                  color: page.orbColor,
                ),
              ),
              AnimatedBuilder(
                animation: pulse,
                builder: (_, __) {
                  final scale = 0.9 + pulse.value * 0.16;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            page.orbColor.withValues(alpha: 0.26),
                            page.orbColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: page.orbColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: page.orbColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Icon(page.icon, size: 70, color: page.orbColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingBadge extends StatelessWidget {
  const _FloatingBadge({
    required this.pulse,
    required this.icon,
    required this.color,
  });

  final Animation<double> pulse;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final y = (0.5 - pulse.value) * 8;
        return Transform.translate(
          offset: Offset(0, y),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        );
      },
    );
  }
}

class _PrimaryCtaButton extends StatelessWidget {
  const _PrimaryCtaButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 118),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF00A878),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A878).withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }
}

class _OnboardingBgPainter extends CustomPainter {
  const _OnboardingBgPainter({required this.pulse});

  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF5F6FA),
    );

    final ease = Curves.easeInOut.transform(pulse);

    _drawOrb(
      canvas,
      center: Offset(size.width * 0.78 + ease * 10, size.height * 0.11 - ease * 8),
      radius: size.width * 0.30,
      color: const Color(0xFFDFF9F0),
    );

    _drawOrb(
      canvas,
      center: Offset(size.width * 0.12 - ease * 10, size.height * 0.74 + ease * 8),
      radius: size.width * 0.30,
      color: const Color(0xFFE8F1FF),
    );

    _drawOrb(
      canvas,
      center: Offset(size.width * 0.56 + ease * 6, size.height * 0.38 - ease * 6),
      radius: size.width * 0.18,
      color: const Color(0xFFF4EEFF),
    );

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.015)
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
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_OnboardingBgPainter oldDelegate) => oldDelegate.pulse != pulse;
}
