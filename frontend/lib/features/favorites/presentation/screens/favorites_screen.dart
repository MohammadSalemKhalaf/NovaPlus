import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../guest/data/datasources/guest_remote_data_source.dart';
import '../../../guest/data/repositories/guest_repository_impl.dart';
import '../../../guest/domain/entities/guest_entities.dart';
import '../../../guest/domain/repositories/guest_repository.dart';
import '../../../guest/domain/usecases/list_guest_stores_use_case.dart';
import '../../../guest/presentation/screens/guest_store_details_screen.dart';
import '../../../guest/presentation/widgets/store_card_widget.dart';
import '../favorites_cubit.dart';

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
  static Color border(bool d) => d ? const Color(0xFF222530) : const Color(0xFFE8ECF2);

  static Color shadowCard(bool d) => d ? Colors.black.withValues(alpha: 0.40) : Colors.black.withValues(alpha: 0.06);
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with TickerProviderStateMixin {
  late final ListGuestStoresUseCase _listGuestStoresUseCase;
  late final AnimationController _heroCtrl;
  late final AnimationController _bgPulseCtrl;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _bgPulse;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final remoteDataSource = GuestRemoteDataSource(apiClient: apiClient);
    final GuestRepository repository = GuestRepositoryImpl(
      remoteDataSource: remoteDataSource,
    );
    _listGuestStoresUseCase = ListGuestStoresUseCase(repository);

    _heroCtrl = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
    );
    _heroFade = CurvedAnimation(
      parent: _heroCtrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FavoritesCubit>().loadFavorites();
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _bgPulseCtrl.dispose();
    super.dispose();
  }

  Future<List<GuestStoreEntity>> _loadFavoriteStores(
    FavoritesState state,
  ) async {
    final favoriteIds = state.favoriteStatusByTenant.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();

    if (favoriteIds.isEmpty) {
      return const <GuestStoreEntity>[];
    }

    final stores = await _listGuestStoresUseCase(perPage: 100);
    return stores
        .where((store) => favoriteIds.contains(store.id.toString()))
        .toList(growable: false);
  }

  Future<void> _toggleFavorite(GuestStoreEntity store) async {
    final cubit = context.read<FavoritesCubit>();
    final authState = context.read<AuthState>();

    await cubit.toggleFavorite(store.id.toString());
    final state = cubit.state;

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    if (state.statusCode == 401) {
      await authState.setUnauthenticated();
      if (!mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Session expired. Please log in again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    if (state.statusCode == 403) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('You are not allowed to update favorites.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    if (state.error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      cubit.clearError();
    }
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(d),
                      Expanded(
                        child: Consumer<FavoritesCubit>(
                          builder: (context, cubit, _) {
                            final state = cubit.state;
                            return FutureBuilder<List<GuestStoreEntity>>(
                              future: _loadFavoriteStores(state),
                              builder: (context, snapshot) {
                                if (state.loading && !snapshot.hasData) {
                                  return _buildShimmerList(d);
                                }

                                if (snapshot.hasError) {
                                  return _buildErrorState(
                                    d,
                                    onRetry: cubit.loadFavorites,
                                  );
                                }

                                final stores = snapshot.data ?? const <GuestStoreEntity>[];

                                if (stores.isEmpty) {
                                  return _buildEmptyState(d);
                                }

                                return RefreshIndicator(
                                  onRefresh: cubit.loadFavorites,
                                  color: _DT.accent(d),
                                  backgroundColor: _DT.glass(d),
                                  child: ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                                    itemCount: stores.length + 1,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
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
                                                '${stores.length} Favorites',
                                                style: TextStyle(
                                                  color: _DT.muted(d),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Container(
                                                  height: 1,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        _DT.border(d),
                                                        _DT.border(d).withValues(alpha: 0),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      final store = stores[index - 1];
                                      final tenantId = store.id.toString();
                                      final isFavorite = cubit.isFavorite(tenantId);

                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(22),
                                          color: _DT.glass(d),
                                          border: Border.all(color: _DT.glassBorder(d)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _DT.shadowCard(d),
                                              blurRadius: 12,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(21),
                                          child: StoreCardWidget(
                                            store: store,
                                            onTap: () {
                                              final favoritesCubit = context.read<FavoritesCubit>();
                                              Navigator.push<void>(
                                                context,
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      ChangeNotifierProvider<FavoritesCubit>.value(
                                                    value: favoritesCubit,
                                                    child: GuestStoreDetailsScreen(
                                                      initialStore: store,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                            trailing: IconButton(
                                              onPressed: () => _toggleFavorite(store),
                                              icon: Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: _DT.accentSoft(d),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isFavorite
                                                      ? Icons.favorite_rounded
                                                      : Icons.favorite_border_rounded,
                                                  color: const Color(0xFFFF6B8A),
                                                  size: 18,
                                                ),
                                              ),
                                              tooltip: 'Remove favorite',
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            );
                          },
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
    );
  }

  Widget _buildHeader(bool d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                  'المفضلة',
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
                  'Favorite Stores',
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
            child: Icon(Icons.favorite_rounded, color: _DT.text(d), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList(bool d) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      itemCount: 5,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ShimmerCard(d: d),
        );
      },
    );
  }

  Widget _buildEmptyState(bool d) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _DT.glass(d),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _DT.glassBorder(d)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: _DT.accentSoft(d),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: _DT.accent(d).withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.favorite_border_rounded, color: _DT.accent(d), size: 38),
              ),
              const SizedBox(height: 18),
              Text(
                'No favorites yet',
                style: TextStyle(
                  color: _DT.text(d),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart icon on a store to add it here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _DT.muted(d), fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool d, {required Future<void> Function() onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _DT.glass(d),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _DT.glassBorder(d)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: d ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'Unable to load favorites',
                style: TextStyle(
                  color: _DT.text(d),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again in a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _DT.muted(d), fontSize: 13.5),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: _DT.accent(d),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: d ? const Color(0xFF0B0C10) : Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Retry',
                        style: TextStyle(
                          color: d ? const Color(0xFF0B0C10) : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
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
  _BgPainter({required this.d, required this.t, required this.size});

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
  const _GlassIconButton({required this.d, required this.child});

  final bool d;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
    );
  }
}

class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({required this.d});

  final bool d;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1300), vsync: this)
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final base = d ? const Color(0xFF1A1C23) : const Color(0xFFECEFF4);
    final high = d ? const Color(0xFF22252F) : const Color(0xFFF5F7FA);
    final block = d ? const Color(0xFF111318) : const Color(0xFFE0E5EC);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: [base, high, base],
            ),
          ),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.all(14),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: block,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 15,
                        width: 130,
                        decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 11,
                        width: 85,
                        decoration: BoxDecoration(
                          color: block,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
