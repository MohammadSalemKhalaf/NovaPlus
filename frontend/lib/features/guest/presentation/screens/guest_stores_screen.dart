import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../favorites/presentation/favorites_cubit.dart';
import '../../data/datasources/guest_remote_data_source.dart';
import '../../data/repositories/guest_repository_impl.dart';
import '../../domain/entities/guest_entities.dart';
import '../../domain/repositories/guest_repository.dart';
import '../../domain/usecases/list_guest_stores_use_case.dart';
import '../widgets/guest_banner_widget.dart';
import '../widgets/store_card_widget.dart';
import 'guest_store_details_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DESIGN TOKENS — matches GuestShellScreen palette exactly
// ─────────────────────────────────────────────────────────────────────────────

class _DT {
  // ── Accent
  static Color accent(bool d)      => d ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
  static Color accentSoft(bool d)  => d ? const Color(0xFF5CE1B0).withOpacity(0.14) : const Color(0xFF00A878).withOpacity(0.10);
  static Color accentGlow(bool d)  => d ? const Color(0xFF5CE1B0).withOpacity(0.30) : const Color(0xFF00A878).withOpacity(0.22);
  static Color accentWarm(bool d)  => d ? const Color(0xFFFFB347) : const Color(0xFFF59E0B);

  // ── Backgrounds
  static Color bgBase(bool d)      => d ? const Color(0xFF0B0C10) : const Color(0xFFF5F6FA);
  static Color bgSurface(bool d)   => d ? const Color(0xFF141519) : const Color(0xFFFFFFFF);
  static Color bgCard(bool d)      => d ? const Color(0xFF1A1C23) : const Color(0xFFFFFFFF);

  // ── Orbs
  static Color orb1(bool d)        => d ? const Color(0xFF1A3A4A) : const Color(0xFFD6F5EC);
  static Color orb2(bool d)        => d ? const Color(0xFF0D1F35) : const Color(0xFFE0EDFF);
  static Color orb3(bool d)        => d ? const Color(0xFF221A3A) : const Color(0xFFF0E5FF);

  // ── Glass
  static Color glass(bool d)       => d ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.80);
  static Color glassBorder(bool d) => d ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);

  // ── Text
  static Color text(bool d)        => d ? const Color(0xFFF0F0F5) : const Color(0xFF0F1117);
  static Color muted(bool d)       => d ? const Color(0xFF9095A8) : const Color(0xFF6B7280);
  static Color hint(bool d)        => d ? const Color(0xFF555B70) : const Color(0xFFB0B7C3);
  static Color border(bool d)      => d ? const Color(0xFF222530) : const Color(0xFFE8ECF2);

  // ── Shadow
  static Color shadowDeep(bool d)  => d ? Colors.black.withOpacity(0.50) : Colors.black.withOpacity(0.08);
  static Color shadowCard(bool d)  => d ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.05);

  // ── Status badge
  static Color statusOpen(bool d)  => d ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
  static Color statusBusy(bool d)  => d ? const Color(0xFFFFB347) : const Color(0xFFF59E0B);
  static Color statusClosed(bool d)=> d ? const Color(0xFFFF6B6B) : const Color(0xFFEF4444);

  // ── Shimmer
  static Color shimBase(bool d)    => d ? const Color(0xFF1A1C23) : const Color(0xFFECEDF1);
  static Color shimHigh(bool d)    => d ? const Color(0xFF22252F) : const Color(0xFFF5F6FA);
  static Color shimBlock(bool d)   => d ? const Color(0xFF111318) : const Color(0xFFE2E4EA);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class GuestStoresScreen extends StatefulWidget {
  const GuestStoresScreen({super.key});

  @override
  State<GuestStoresScreen> createState() => _GuestStoresScreenState();
}

class _GuestStoresScreenState extends State<GuestStoresScreen>
    with TickerProviderStateMixin {

  late final ListGuestStoresUseCase _listGuestStoresUseCase;
  late Future<List<GuestStoreEntity>>   _storesFuture;
  late Future<List<BusinessTypeEntity>> _businessTypesFuture;

  final TextEditingController _searchController = TextEditingController();
  Timer?  _searchDebounce;
  String  _searchQuery            = '';
  int?    _selectedBusinessTypeId;

  // ── Animations
  late AnimationController _heroCtrl;
  late AnimationController _bgPulseCtrl;
  late Animation<double>   _heroFade;
  late Animation<Offset>   _heroSlide;
  late Animation<double>   _bgPulse;

  final ScrollController _scrollCtrl = ScrollController();
  double _scrollOffset = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _initDependencies();
    _initAnimations();
    _scrollCtrl.addListener(
      () => setState(() => _scrollOffset = _scrollCtrl.offset),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthState>().isAuthenticated) {
        context.read<FavoritesCubit>().loadFavorites();
      }
    });
  }

  void _initDependencies() {
    final storage   = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final remote    = GuestRemoteDataSource(apiClient: apiClient);
    final GuestRepository repo = GuestRepositoryImpl(remoteDataSource: remote);
    _listGuestStoresUseCase = ListGuestStoresUseCase(repo);
    _storesFuture           = _loadStores();
    _businessTypesFuture    = _loadBusinessTypes();
  }

  void _initAnimations() {
    _heroCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _heroFade = CurvedAnimation(
        parent: _heroCtrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut));
    _heroSlide = Tween<Offset>(
            begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _heroCtrl,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)));

    _bgPulseCtrl = AnimationController(
        duration: const Duration(seconds: 7), vsync: this)
      ..repeat(reverse: true);
    _bgPulse = CurvedAnimation(
        parent: _bgPulseCtrl, curve: Curves.easeInOut);

    _heroCtrl.forward();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _heroCtrl.dispose();
    _bgPulseCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<List<GuestStoreEntity>> _loadStores() =>
      _listGuestStoresUseCase(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        businessTypeId: _selectedBusinessTypeId,
        perPage: 10,
      );

  Future<List<BusinessTypeEntity>> _loadBusinessTypes() async {
    final all = await _listGuestStoresUseCase(perPage: 100);
    final map = SplayTreeMap<int, BusinessTypeEntity>();
    for (final s in all) {
      final t = s.businessType;
      if (t != null) map[t.id] = t;
    }
    return map.values.toList(growable: false);
  }

  void _onSearchChanged(String value) {
    _searchQuery = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _storesFuture = _loadStores());
    });
  }

  Future<void> _reload() async {
    HapticFeedback.mediumImpact();
    if (context.read<AuthState>().isAuthenticated) {
      await context.read<FavoritesCubit>().loadFavorites();
    }
    setState(() {
      _storesFuture        = _loadStores();
      _businessTypesFuture = _loadBusinessTypes();
    });
    await _storesFuture;
  }

  void _onSelectBusinessType(int? id) {
    if (_selectedBusinessTypeId == id) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedBusinessTypeId = id;
      _storesFuture           = _loadStores();
    });
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
            // ── Atmospheric background (matches shell)
            _AtmosphericBackground(d: d, pulse: _bgPulse),

            // ── Content
            SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _heroFade,
                child: SlideTransition(
                  position: _heroSlide,
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    color: _DT.accent(d),
                    backgroundColor: _DT.bgSurface(d),
                    child: CustomScrollView(
                      controller: _scrollCtrl,
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      slivers: [
                        _buildHeader(d),
                        _buildSearch(d),
                        _buildFilter(d),
                        if (!context.watch<AuthState>().isAuthenticated)
                          _buildBanner(),
                        _buildStores(d),
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool d) {
    final collapsed = _scrollOffset > 50;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Brand badge
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 260),
                    opacity: collapsed ? 0 : 1,
                    child: AnimatedBuilder(
                      animation: _bgPulse,
                      builder: (_, __) {
                        return Row(
                          children: [
                            Container(
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
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  // ── Title
                  Text(
                    'المتاجر',
                    style: TextStyle(
                      color: _DT.text(d),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Discover Stores',
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
            // ── Glass icon button
            _GlassIconButton(
              d: d,
              onTap: () {},
              child: AnimatedBuilder(
                animation: _bgPulse,
                builder: (_, __) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.storefront_rounded,
                        color: _DT.text(d), size: 22),
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _DT.accent(d),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _DT.accentGlow(d),
                              blurRadius: 6 * _bgPulse.value,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Widget _buildSearch(bool d) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              decoration: BoxDecoration(
                color: _DT.glass(d),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _DT.glassBorder(d)),
                boxShadow: d
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'ابحث عن متجر...',
                  hintStyle: TextStyle(color: _DT.hint(d), fontSize: 14),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(11),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _DT.accentSoft(d),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.search_rounded,
                        color: _DT.accent(d), size: 17),
                  ),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _DT.border(d),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded,
                                color: _DT.muted(d), size: 13),
                          ),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter Chips ──────────────────────────────────────────────────────────

  Widget _buildFilter(bool d) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 52,
        child: FutureBuilder<List<BusinessTypeEntity>>(
          future: _businessTypesFuture,
          builder: (ctx, snapshot) {
            final types = snapshot.data ?? const <BusinessTypeEntity>[];
            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              children: [
                _FilterChip(
                  label: 'الكل',
                  selected: _selectedBusinessTypeId == null,
                  d: d,
                  onTap: () => _onSelectBusinessType(null),
                ),
                ...types.map((t) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: t.name,
                        selected: _selectedBusinessTypeId == t.id,
                        d: d,
                        onTap: () => _onSelectBusinessType(t.id),
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBanner() => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: GuestBannerWidget(),
        ),
      );

  // ── Stores List ───────────────────────────────────────────────────────────

  Widget _buildStores(bool d) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<GuestStoreEntity>>(
        future: _storesFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerList(d);
          }
          if (snapshot.hasError) {
            return _buildError('${snapshot.error}', d);
          }
          final stores = snapshot.data ?? const <GuestStoreEntity>[];
          if (stores.isEmpty) return _buildEmpty(d);
          return _buildList(stores, d);
        },
      ),
    );
  }

  Widget _buildList(List<GuestStoreEntity> stores, bool d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _DT.accent(d),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stores.length} متجر',
                style: TextStyle(
                  color: _DT.muted(d),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _DT.border(d),
                      _DT.border(d).withOpacity(0),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          // ── Cards
          ...stores.asMap().entries.map((e) {
            return _StaggerCard(
              index: e.key,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _StoreCard(
                  store: e.value,
                  d: d,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final fav = context.read<FavoritesCubit>();
                    Navigator.push<void>(
                      context,
                      _SmoothRoute(
                        builder: (_) =>
                            ChangeNotifierProvider<FavoritesCubit>.value(
                          value: fav,
                          child: GuestStoreDetailsScreen(
                              initialStore: e.value),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShimmerList(bool d) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          children: List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ShimmerCard(delay: i * 100, d: d),
            ),
          ),
        ),
      );

  Widget _buildError(String message, bool d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: const Color(0xFFDC2626).withOpacity(0.08),
                border: Border.all(
                    color: const Color(0xFFDC2626).withOpacity(0.3)),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
            ),
            const SizedBox(height: 18),
            Text('تعذّر تحميل المتاجر',
                style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: _DT.muted(d), fontSize: 13)),
            const SizedBox(height: 24),
            _AccentButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              d: d,
              onTap: () => setState(() => _storesFuture = _loadStores()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool d) {
    final hasSearch = _searchQuery.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: _DT.accentSoft(d),
                border: Border.all(
                    color: _DT.accent(d).withOpacity(0.28), width: 1),
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.storefront_rounded,
                color: _DT.accent(d),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch
                  ? 'لا نتائج لـ "$_searchQuery"'
                  : 'لا توجد متاجر',
              style: TextStyle(
                  color: _DT.text(d),
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'جرّب تعديل البحث أو تصفّح جميع المتاجر'
                  : 'لا توجد متاجر متاحة في الوقت الحالي',
              textAlign: TextAlign.center,
              style: TextStyle(color: _DT.muted(d), fontSize: 13),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 24),
              _AccentButton(
                label: 'مسح البحث',
                icon: Icons.clear_rounded,
                d: d,
                onTap: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ATMOSPHERIC BACKGROUND — mirrors GuestShellScreen exactly
// ─────────────────────────────────────────────────────────────────────────────

class _AtmosphericBackground extends StatelessWidget {
  final bool d;
  final Animation<double> pulse;

  const _AtmosphericBackground({required this.d, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) => CustomPaint(
          painter: _BgPainter(d: d, t: pulse.value, size: size),
        ),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  final bool d;
  final double t;
  final Size size;

  _BgPainter({required this.d, required this.t, required this.size});

  @override
  void paint(Canvas canvas, Size _) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _DT.bgBase(d),
    );

    final e = Curves.easeInOut.transform(t);

    _drawOrb(canvas,
        center: Offset(size.width * 0.82 + e * 12, size.height * 0.08 - e * 10),
        radius: size.width * 0.52,
        color: _DT.orb1(d));
    _drawOrb(canvas,
        center: Offset(size.width * 0.1 - e * 10, size.height * 0.78 + e * 8),
        radius: size.width * 0.45,
        color: _DT.orb2(d));
    _drawOrb(canvas,
        center: Offset(size.width * 0.55 + e * 6, size.height * 0.42 - e * 6),
        radius: size.width * 0.30,
        color: _DT.orb3(d));

    // Dot grid
    final paint = Paint()
      ..color = (d ? Colors.white : Colors.black).withOpacity(0.028)
      ..strokeCap = StrokeCap.round;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  void _drawOrb(Canvas canvas,
      {required Offset center, required double radius, required Color color}) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t || old.d != d;
}

// ─────────────────────────────────────────────────────────────────────────────
//  GLASS ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final bool d;
  final VoidCallback onTap;
  final Widget child;

  const _GlassIconButton(
      {required this.d, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _DT.glass(d),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _DT.glassBorder(d)),
              boxShadow: d
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STORE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StoreCard extends StatefulWidget {
  const _StoreCard(
      {required this.store, required this.d, required this.onTap});
  final GuestStoreEntity store;
  final bool d;
  final VoidCallback onTap;

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 110), vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.972).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return GestureDetector(
      onTapDown: (_) {
        _ctrl.forward();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        _ctrl.reverse();
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        _ctrl.reverse();
        setState(() => _pressed = false);
      },
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _DT.bgCard(d),
            border: Border.all(
              color: _pressed
                  ? _DT.accent(d).withOpacity(d ? 0.45 : 0.50)
                  : _DT.border(d),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _DT.shadowCard(d),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              if (_pressed)
                BoxShadow(
                  color: _DT.accentGlow(d),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child:
                StoreCardWidget(store: widget.store, onTap: widget.onTap),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.d,
    required this.onTap,
  });
  final String label;
  final bool selected, d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: selected ? _DT.accent(d) : _DT.glass(d),
          border: Border.all(
            color: selected
                ? _DT.accent(d)
                : _DT.glassBorder(d),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _DT.accentGlow(d),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (d ? const Color(0xFF0B0C10) : Colors.white)
                : _DT.muted(d),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ACCENT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _AccentButton extends StatelessWidget {
  const _AccentButton({
    required this.label,
    required this.icon,
    required this.d,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _DT.accent(d),
          boxShadow: [
            BoxShadow(
              color: _DT.accentGlow(d),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: d ? const Color(0xFF0B0C10) : Colors.white,
                size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: d ? const Color(0xFF0B0C10) : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  STAGGER CARD WRAPPER
// ─────────────────────────────────────────────────────────────────────────────

class _StaggerCard extends StatefulWidget {
  const _StaggerCard({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggerCard> createState() => _StaggerCardState();
}

class _StaggerCardState extends State<_StaggerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: Duration(milliseconds: 480 + widget.index * 50),
        vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(
      Duration(milliseconds: widget.index * 70),
      () => mounted ? _ctrl.forward() : null,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHIMMER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.delay, required this.d});
  final int delay;
  final bool d;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _anim = Tween<double>(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () => mounted ? _ctrl.repeat() : null);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0.3),
            end: Alignment(_anim.value + 1, 0.3),
            colors: [
              _DT.shimBase(d),
              _DT.shimHigh(d),
              _DT.shimBase(d),
            ],
          ),
        ),
        child: Row(children: [
          Container(
            margin: const EdgeInsets.all(13),
            width: 74,
            height: 74,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _DT.shimBlock(d)),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      height: 14,
                      width: 125,
                      decoration: BoxDecoration(
                          color: _DT.shimBlock(d),
                          borderRadius: BorderRadius.circular(7))),
                  const SizedBox(height: 10),
                  Container(
                      height: 10,
                      width: 82,
                      decoration: BoxDecoration(
                          color: _DT.shimBlock(d),
                          borderRadius: BorderRadius.circular(5))),
                  const SizedBox(height: 9),
                  Container(
                      height: 10,
                      width: 52,
                      decoration: BoxDecoration(
                          color: _DT.shimBlock(d),
                          borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SMOOTH PAGE ROUTE
// ─────────────────────────────────────────────────────────────────────────────

class _SmoothRoute<T> extends PageRouteBuilder<T> {
  _SmoothRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (ctx, _, __) => builder(ctx),
          transitionsBuilder: (_, animation, __, child) {
            final fade = CurvedAnimation(
                parent: animation, curve: Curves.easeOut);
            final slide = Tween<Offset>(
                    begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic));
            return FadeTransition(
                opacity: fade,
                child: SlideTransition(position: slide, child: child));
          },
          transitionDuration: const Duration(milliseconds: 340),
        );
}