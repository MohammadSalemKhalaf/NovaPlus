import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/notifications/local_notifications_service.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/state/cart_state.dart';
import '../../../../core/state/store_cubit.dart';
import '../../../../core/state/theme_state.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../cart/presentation/screens/cart_screen.dart';
import '../../../cart/presentation/widgets/cart_icon_with_badge.dart';
import '../../../favorites/presentation/favorites_cubit.dart';
import '../../data/datasources/guest_remote_data_source.dart';
import '../../data/repositories/guest_repository_impl.dart';
import '../../domain/entities/guest_entities.dart';
import '../../domain/repositories/guest_repository.dart';
import '../../domain/usecases/get_guest_categories_use_case.dart';
import '../../domain/usecases/get_guest_item_detail_use_case.dart';
import '../../domain/usecases/get_guest_items_use_case.dart';
import '../../domain/usecases/get_guest_store_details_use_case.dart';
import '../services/guest_notifications_service.dart';
import '../widgets/guest_banner_widget.dart';
import 'guest_store_chat_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS — Unified with Stores / Orders / Profile / Favorites
// ═══════════════════════════════════════════════════════════════════════════

class _T {
  // ─── LIGHT ───────────────────────────────────────────────────────────────
  static const lBg            = Color(0xFFF5F6FA);
  static const lSurface       = Color(0xFFFFFFFF);
  static const lCard          = Color(0xFFFFFFFF);
  static const lBorder        = Color(0xFFE8ECF2);
  static const lAccent        = Color(0xFF00A878);
  static const lAccentSoft    = Color(0xFFD6F5EC);
  static const lText          = Color(0xFF0F1117);
  static const lTextMuted     = Color(0xFF6B7280);
  static const lTextSub       = Color(0xFFB0B7C3);
  static const lWarm          = Color(0xFFF59E0B);
  static const lError         = Color(0xFFEF4444);

  // ─── DARK ────────────────────────────────────────────────────────────────
  static const dBg            = Color(0xFF0B0C10);
  static const dSurface       = Color(0xFF141519);
  static const dCard          = Color(0xFF1A1C23);
  static const dBorder        = Color(0xFF222530);
  static const dAccent        = Color(0xFF5CE1B0);
  static const dAccentSoft    = Color(0xFF1A3A4A);
  static const dText          = Color(0xFFF0F0F5);
  static const dTextMuted     = Color(0xFF9095A8);
  static const dTextSub       = Color(0xFF555B70);
  static const dWarm          = Color(0xFFFFB347);
  static const dError         = Color(0xFFEF4444);

  static Color bg(bool d)           => d ? dBg           : lBg;
  static Color surface(bool d)      => d ? dSurface      : lSurface;
  static Color card(bool d)         => d ? dCard         : lCard;
  static Color border(bool d)       => d ? dBorder       : lBorder;
  static Color accent(bool d)       => d ? dAccent       : lAccent;
  static Color accentSoft(bool d)   => d ? dAccentSoft   : lAccentSoft;
  static Color text(bool d)         => d ? dText         : lText;
  static Color muted(bool d)        => d ? dTextMuted    : lTextMuted;
  static Color sub(bool d)          => d ? dTextSub      : lTextSub;
  static Color warm(bool d)         => d ? dWarm         : lWarm;
  static Color error(bool d)        => d ? dError        : lError;
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class GuestStoreDetailsScreen extends StatefulWidget {
  const GuestStoreDetailsScreen({super.key, required this.initialStore});
  final GuestStoreEntity initialStore;

  @override
  State<GuestStoreDetailsScreen> createState() =>
      _GuestStoreDetailsScreenState();
}

class _GuestStoreDetailsScreenState extends State<GuestStoreDetailsScreen>
    with TickerProviderStateMixin {

  // ── Use cases ─────────────────────────────────────────────────────────────
  late final GetGuestStoreDetailsUseCase  _getGuestStoreDetailsUseCase;
  late final GetGuestCategoriesUseCase    _getGuestCategoriesUseCase;
  late final GetGuestItemsUseCase         _getGuestItemsUseCase;
  late final GetGuestItemDetailUseCase    _getGuestItemDetailUseCase;
  late final GuestNotificationsService    _guestNotificationsService;

  // ── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();
  Timer?  _searchDebounce;
  Timer?  _chatUnreadPollingTimer;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _pageCtrl;     // page entrance
  late AnimationController _headerCtrl;   // header parallax pulse
  late AnimationController _shimmerCtrl;  // shimmer sweep
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;
  late Animation<double>   _headerScale;
  late Animation<double>   _shimmerAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  GuestStoreDetailEntity?   _storeDetails;
  List<GuestCategoryEntity> _categories     = const [];
  List<GuestItemListEntity> _items          = const [];
  int    _totalItemsCount   = 0;
  bool   _isLoadingStore    = true;
  bool   _isLoadingItems    = false;
  String? _errorMessage;
  int    _chatUnreadCount   = 0;
  int?   _selectedCategoryId;
  String _itemSearchQuery   = '';
  double _scrollOffset      = 0;

  // ── Computed ──────────────────────────────────────────────────────────────
  bool get _isDark =>
      context.read<ThemeState>().isDarkMode;

  @override
  void initState() {
    super.initState();
    _initDeps();
    _initAnimations();
    _scrollController.addListener(
      () => setState(() => _scrollOffset = _scrollController.offset),
    );
    _loadInitialData();
    unawaited(LocalNotificationsService.instance.requestPermission());
    _refreshChatUnreadCount();
    _startChatUnreadPolling();
  }

  void _initDeps() {
    final storage        = SecureStorage();
    final apiClient      = ApiClient(secureStorage: storage);
    _guestNotificationsService =
        GuestNotificationsService(apiClient: apiClient);
    final remote = GuestRemoteDataSource(apiClient: apiClient);
    final GuestRepository repo = GuestRepositoryImpl(remoteDataSource: remote);
    _getGuestStoreDetailsUseCase = GetGuestStoreDetailsUseCase(repo);
    _getGuestCategoriesUseCase   = GetGuestCategoriesUseCase(repo);
    _getGuestItemsUseCase        = GetGuestItemsUseCase(repo);
    _getGuestItemDetailUseCase   = GetGuestItemDetailUseCase(repo);
  }

  void _initAnimations() {
    _pageCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _pageFade = CurvedAnimation(
        parent: _pageCtrl, curve: const Interval(0, 0.75, curve: Curves.easeOut));
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _pageCtrl,
            curve: const Interval(0, 0.85, curve: Curves.easeOutCubic)));

    _headerCtrl = AnimationController(
        duration: const Duration(milliseconds: 3000), vsync: this)
      ..repeat(reverse: true);
    _headerScale = Tween<double>(begin: 1.0, end: 1.04).animate(
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeInOut));

    _shimmerCtrl = AnimationController(
        duration: const Duration(milliseconds: 1400), vsync: this)
      ..repeat();
    _shimmerAnim = Tween<double>(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _chatUnreadPollingTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _pageCtrl.dispose();
    _headerCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Chat polling ──────────────────────────────────────────────────────────
  void _startChatUnreadPolling() {
    _chatUnreadPollingTimer?.cancel();
    _chatUnreadPollingTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refreshChatUnreadCount(),
    );
  }

  Future<void> _refreshChatUnreadCount() async {
    if (!mounted) return;
    final auth = context.read<AuthState>();
    if (!auth.isAuthenticated) {
      if (_chatUnreadCount != 0) setState(() => _chatUnreadCount = 0);
      return;
    }
    try {
      final unread = await _guestNotificationsService.unreadCount();
      if (!mounted) return;
      setState(() => _chatUnreadCount = unread);
    } catch (_) {}
  }

  // ── Fallback ──────────────────────────────────────────────────────────────
  GuestStoreDetailEntity _fallbackStoreDetails() => GuestStoreDetailEntity(
        id: widget.initialStore.id,
        name: widget.initialStore.name,
        slug: widget.initialStore.slug,
        businessMode: 'store',
        image: widget.initialStore.image,
        businessType: widget.initialStore.businessType == null
            ? null
            : BusinessTypeEntity(
                id: widget.initialStore.businessType!.id,
                name: widget.initialStore.businessType!.name,
                slug: widget.initialStore.businessType!.slug,
              ),
        catalogSummary: const CatalogSummaryEntity(
          categoriesCount: 0,
          publicItemsCount: 0,
        ),
      );

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadInitialData() async {
    final auth          = context.read<AuthState>();
    final favCubit      = context.read<FavoritesCubit>();
    final storeCubit    = context.read<StoreCubit>();
    final cartState     = context.read<CartState>();

    setState(() {
      _isLoadingStore = true;
      _isLoadingItems = false;
      _errorMessage   = null;
    });

    try {
      GuestStoreDetailEntity details;
      try {
        details = await _getGuestStoreDetailsUseCase(widget.initialStore.slug);
      } catch (e) {
        details = _fallbackStoreDetails();
      }

      final results = await Future.wait<dynamic>([
        _safeLoadCategories(details.id),
        _safeLoadItems(details.id),
      ]);

      final categories = results[0] as List<GuestCategoryEntity>;
      final items      = results[1] as List<GuestItemListEntity>;

      if (!mounted) return;

      setState(() {
        _storeDetails     = details;
        _categories       = categories;
        _items            = items;
        _totalItemsCount  = items.length;
        _isLoadingStore   = false;
        _isLoadingItems   = false;
      });
      _pageCtrl.forward();

      await SecureStorage().saveTenantId(details.id.toString());

      try {
        storeCubit.setCurrentStore(details.id);
        await cartState.onEnterStore(details.id);
      } catch (_) {}

      if (auth.isAuthenticated) {
        try {
          if (favCubit.state.favoriteStatusByTenant.isEmpty) {
            await favCubit.loadFavorites();
          }
          await favCubit.checkFavorite(details.id.toString());
        } catch (_) {}
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingStore = false;
        _isLoadingItems = false;
        _errorMessage   = _safeUserMessage(error);
      });
    }
  }

  Future<List<GuestCategoryEntity>> _safeLoadCategories(int id) async {
    try { return await _getGuestCategoriesUseCase(id); }
    catch (_) { return const []; }
  }

  Future<List<GuestItemListEntity>> _safeLoadItems(int id) async {
    try {
      return await _getGuestItemsUseCase(id,
          categoryId: _selectedCategoryId,
          search: _itemSearchQuery.isEmpty ? null : _itemSearchQuery);
    } catch (_) { return const []; }
  }

  String _safeUserMessage(Object e) {
    if (e is DioException) {
      final s = e.response?.statusCode;
      if (s == 404) return 'Store is not available right now.';
      if (s != null && s >= 500)
        return 'Store is temporarily unavailable. Please try again shortly.';
    }
    return 'Unable to load store right now. Please try again.';
  }

  Future<void> _loadItems() async {
    final details = _storeDetails;
    if (details == null) return;
    setState(() => _isLoadingItems = true);
    try {
      final items = await _getGuestItemsUseCase(details.id,
          categoryId: _selectedCategoryId,
          search: _itemSearchQuery.isEmpty ? null : _itemSearchQuery);
      if (!mounted) return;
      setState(() {
        _items = items;
        if (_selectedCategoryId == null && _itemSearchQuery.isEmpty)
          _totalItemsCount = items.length;
        _isLoadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _items = const []; _isLoadingItems = false; });
    }
  }

  void _onItemSearchChanged(String value) {
    _itemSearchQuery = value.trim();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadItems();
    });
  }

  void _onSelectCategory(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedCategoryId = categoryId);
    _loadItems();
  }

  // ── Item detail modal ─────────────────────────────────────────────────────
  Future<void> _showItemDetails(GuestItemListEntity item, int tenantId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final detail = await _getGuestItemDetailUseCase(tenantId, item.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ItemDetailModal(detail: detail),
      );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_errorSnack('Unable to load item: $e'));
    }
  }

  // ── Cart ──────────────────────────────────────────────────────────────────
  Future<void> _handleAddToCart(GuestItemListEntity item, int tenantId) async {
    final messenger = ScaffoldMessenger.of(context);
    final cartState = context.read<CartState>();
    try {
      await cartState.addItem(
          itemId: item.id, quantity: 1, storeId: tenantId);
      if (!mounted) return;

      final switchMsg = cartState.storeSwitchMessage;
      if (switchMsg != null && switchMsg.isNotEmpty) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(_successSnack(switchMsg));
        cartState.clearStoreSwitchMessage();
      }

      final err = cartState.errorMessage;
      if (err == null) {
        await cartState.fetchCart(storeId: tenantId);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(_successSnack('تمت الإضافة للسلة ✓'));
      } else {
        if (err.contains('different store')) {
          await _showClearCartDialog(item, tenantId);
        } else {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(_errorSnack(err));
        }
      }
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_errorSnack('$e'));
    }
  }

  // ── Chat ──────────────────────────────────────────────────────────────────
  Future<void> _openChat() async {
    final details = _storeDetails;
    if (details == null) return;
    final store = GuestStoreEntity(
      id: details.id, name: details.name, slug: details.slug,
      image: details.image, businessType: details.businessType,
    );
    if (_chatUnreadCount != 0) setState(() => _chatUnreadCount = 0);
    await Navigator.push<void>(context,
        MaterialPageRoute<void>(builder: (_) => GuestStoreChatScreen(store: store)));
    await _refreshChatUnreadCount();
  }

  // ── Clear cart dialog ─────────────────────────────────────────────────────
  Future<void> _showClearCartDialog(
      GuestItemListEntity item, int tenantId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'مسح السلة؟',
        message: 'سلتك تحتوي على منتجات من متجر آخر. هل تريد مسحها وإضافة هذا المنتج؟',
        confirmText: 'مسح وإضافة',
        cancelText: 'إلغاء',
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    if (result != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final cartState = context.read<CartState>();
      await cartState.clearCart(storeId: tenantId);
      await cartState.addItem(
          itemId: item.id, quantity: 1, storeId: tenantId);
      if (!mounted) return;
      if (cartState.errorMessage == null) {
        await cartState.fetchCart(storeId: tenantId);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(_successSnack('تمت الإضافة للسلة ✓'));
      } else {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(_errorSnack(cartState.errorMessage!));
      }
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_errorSnack('$e'));
    }
  }

  // ── Favorite ──────────────────────────────────────────────────────────────
  Future<void> _toggleFavorite() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth      = context.read<AuthState>();
    final favCubit  = context.read<FavoritesCubit>();
    final details   = _storeDetails;
    if (details == null) return;
    if (!auth.isAuthenticated) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(_errorSnack('يرجى تسجيل الدخول لإدارة المفضلة'));
      return;
    }
    HapticFeedback.lightImpact();
    final tenantId  = details.id.toString();
    final wasFav    = favCubit.isFavorite(tenantId);
    await favCubit.toggleFavorite(tenantId);
    if (!mounted) return;
    final state = favCubit.state;
    if (state.statusCode == 401) {
      await auth.setUnauthenticated();
      if (!mounted) return;
      messenger..hideCurrentSnackBar()
        ..showSnackBar(_errorSnack('انتهت الجلسة. يرجى تسجيل الدخول مجدداً.'));
      return;
    }
    if (state.error != null) {
      messenger..hideCurrentSnackBar()..showSnackBar(_errorSnack(state.error!));
      favCubit.clearError();
      return;
    }
    final nowFav = favCubit.isFavorite(tenantId);
    if (nowFav != wasFav) {
      messenger..hideCurrentSnackBar()
        ..showSnackBar(_successSnack(
            nowFav ? 'تمت إضافة المتجر للمفضلة ♥' : 'تمت إزالة المتجر من المفضلة'));
    }
  }

  // ── Snack helpers ─────────────────────────────────────────────────────────
  SnackBar _successSnack(String msg) => SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_rounded,
              color: _T.accent(_isDark), size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: TextStyle(color: _T.text(_isDark)))),
        ]),
        backgroundColor: _T.surface(_isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _T.accent(_isDark).withValues(alpha: 0.4))),
        duration: const Duration(milliseconds: 1800),
      );

  SnackBar _errorSnack(String msg) => SnackBar(
        content: Text(msg, style: TextStyle(color: _T.text(_isDark))),
        backgroundColor: _T.surface(_isDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _T.error(_isDark).withValues(alpha: 0.5))),
      );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final d = context.watch<ThemeState>().isDarkMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: d
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _T.bg(d),
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            _buildAtmosphere(d),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildFloatingAppBar(d),
                  Expanded(
                    child: _isLoadingStore
                        ? _buildLoadingBody(d)
                        : _errorMessage != null
                            ? _buildErrorBody(d)
                            : FadeTransition(
                                opacity: _pageFade,
                                child: SlideTransition(
                                  position: _pageSlide,
                                  child: _buildMainBody(d),
                                ),
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

  // ── Atmosphere ────────────────────────────────────────────────────────────
  Widget _buildAtmosphere(bool d) {
    return Stack(children: [
      Container(color: _T.bg(d)),
      Positioned(
        top: -120, right: -80,
        child: AnimatedBuilder(
          animation: _headerCtrl,
          builder: (_, __) => Transform.scale(
            scale: _headerScale.value,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _T.accent(d).withValues(alpha: d ? 0.10 : 0.06),
                  _T.accent(d).withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 120, left: -60,
        child: AnimatedBuilder(
          animation: _headerCtrl,
          builder: (_, __) => Transform.scale(
            scale: 2.0 - _headerScale.value,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _T.warm(d).withValues(alpha: d ? 0.08 : 0.04),
                  _T.warm(d).withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Floating App Bar ──────────────────────────────────────────────────────
  Widget _buildFloatingAppBar(bool d) {
    final collapsed = _scrollOffset > 40;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.fromLTRB(16, collapsed ? 8 : 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: collapsed
            ? _T.surface(d).withValues(alpha: d ? 0.92 : 0.96)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: collapsed
            ? Border.all(color: _T.border(d), width: 1)
            : null,
        boxShadow: collapsed
            ? [BoxShadow(
                color: Colors.black.withValues(alpha: d ? 0.25 : 0.10),
                blurRadius: 20, offset: const Offset(0, 6))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: collapsed
              ? ImageFilter.blur(sigmaX: 16, sigmaY: 16)
              : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: Row(
            children: [
              // Back
              _AppBarIconButton(
                icon: Icons.arrow_back_rounded,
                d: d,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              // Title
              Expanded(
                child: Text(
                  widget.initialStore.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _T.text(d),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              // Chat
              _AppBarIconButton(
                d: d,
                onTap: _openChat,
                badge: _chatUnreadCount > 0 ? _chatUnreadCount : null,
                child: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              ),
              const SizedBox(width: 6),
              // Favourite
              Consumer<FavoritesCubit>(
                builder: (_, fav, __) {
                  final isFav = _storeDetails != null
                      ? fav.isFavorite(_storeDetails!.id.toString())
                      : false;
                  return _AppBarIconButton(
                    d: d,
                    onTap: _toggleFavorite,
                    child: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: isFav ? const Color(0xFFE05C7B) : _T.muted(d),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              // Cart
              CartIconWithBadge(
                onTap: () async {
                  final cartState = context.read<CartState>();
                  await Navigator.push<void>(context,
                      MaterialPageRoute<void>(
                          builder: (_) => const CartScreen()));
                  if (!mounted) return;
                  await cartState.fetchCart(storeId: _storeDetails?.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading body ──────────────────────────────────────────────────────────
  Widget _buildLoadingBody(bool d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          _buildHeaderSkeleton(d),
          const SizedBox(height: 16),
          _buildSearchSkeleton(d),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12,
                mainAxisSpacing: 12, childAspectRatio: 0.72),
              itemCount: 4,
              itemBuilder: (_, i) => _SkeletonCard(
                  shimmer: _shimmerAnim, d: d, delay: i * 100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton(bool d) => AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (_, __) => Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnim.value - 1, 0),
              end: Alignment(_shimmerAnim.value + 1, 0),
              colors: [_T.card(d), _T.border(d), _T.card(d)],
            ),
          ),
        ),
      );

  Widget _buildSearchSkeleton(bool d) => AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (_, __) => Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnim.value - 1, 0),
              end: Alignment(_shimmerAnim.value + 1, 0),
              colors: [_T.card(d), _T.border(d), _T.card(d)],
            ),
          ),
        ),
      );

  // ── Error body ────────────────────────────────────────────────────────────
  Widget _buildErrorBody(bool d) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: _T.error(d).withValues(alpha: 0.1),
                border: Border.all(
                    color: _T.error(d).withValues(alpha: 0.3), width: 1.5),
              ),
              child: Icon(Icons.error_outline_rounded,
                  color: _T.error(d), size: 36),
            ),
            const SizedBox(height: 20),
            Text('تعذّر تحميل المتجر',
                style: TextStyle(
                    color: _T.text(d),
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _T.muted(d), fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            _AccentButton(
                label: 'إعادة المحاولة',
                icon: Icons.refresh_rounded,
                d: d,
                onTap: _loadInitialData),
          ],
        ),
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────────────────
  Widget _buildMainBody(bool d) {
    final details = _storeDetails!;
    final catsCount = _categories.isNotEmpty
        ? _categories.length
        : details.catalogSummary.categoriesCount;
    final itemsCount = _totalItemsCount > 0
        ? _totalItemsCount
        : details.catalogSummary.publicItemsCount;

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      color: _T.accent(d),
      backgroundColor: _T.surface(d),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          if (!context.watch<AuthState>().isAuthenticated)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: const GuestBannerWidget(),
              ),
            ),
          // ── Header card ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _StoreHeaderCard(
              details: details,
              fallbackImage: widget.initialStore.image,
              categoriesCount: catsCount,
              itemsCount: itemsCount,
              d: d,
              headerScale: _headerScale,
            ),
          ),
          // ── Search ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SearchBar(
                controller: _searchController,
                onChanged: _onItemSearchChanged,
                d: d,
              ),
            ),
          ),
          // ── Category filter ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                children: [
                  _CategoryChip(
                      label: 'الكل',
                      selected: _selectedCategoryId == null,
                      d: d,
                      onTap: () => _onSelectCategory(null)),
                  ..._categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _CategoryChip(
                            label: cat.name,
                            selected: _selectedCategoryId == cat.id,
                            d: d,
                            onTap: () => _onSelectCategory(cat.id)),
                      )),
                ],
              ),
            ),
          ),
          // ── Loading bar ───────────────────────────────────────────────────
          if (_isLoadingItems)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: _T.accent(d),
                    backgroundColor: _T.border(d),
                  ),
                ),
              ),
            ),
          // ── Items grid ────────────────────────────────────────────────────
          if (_items.isEmpty && !_isLoadingItems)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(d: d),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final item = _items[i];
                    return _ItemCard(
                      item: item,
                      index: i,
                      d: d,
                      onTap: () => _showItemDetails(item, details.id),
                      onAddToCart: () => _handleAddToCart(item, details.id),
                    );
                  },
                  childCount: _items.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.70,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// APP BAR ICON BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.d,
    required this.onTap,
    this.icon,
    this.child,
    this.badge,
  });
  final bool d;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? child;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _T.card(d),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _T.border(d), width: 1),
            ),
            child: Center(
              child: child ??
                  Icon(icon, size: 20, color: _T.muted(d)),
            ),
          ),
          if (badge != null)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE05C7B),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge! > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STORE HEADER CARD — cinematic cover + stats
// ═══════════════════════════════════════════════════════════════════════════

class _StoreHeaderCard extends StatelessWidget {
  const _StoreHeaderCard({
    required this.details,
    required this.fallbackImage,
    required this.categoriesCount,
    required this.itemsCount,
    required this.d,
    required this.headerScale,
  });
  final GuestStoreDetailEntity details;
  final String? fallbackImage;
  final int categoriesCount;
  final int itemsCount;
  final bool d;
  final Animation<double> headerScale;

  @override
  Widget build(BuildContext context) {
    final coverUrl = ImageHelper.build(details.image)
        ?? ImageHelper.build(fallbackImage);
    final subtitle = details.businessType?.name ?? details.businessMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _T.surface(d),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _T.border(d), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: d ? 0.3 : 0.08),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              SizedBox(
                height: 195,
                child: AnimatedBuilder(
                  animation: headerScale,
                  builder: (_, __) => Transform.scale(
                    scale: headerScale.value,
                    child: Stack(fit: StackFit.expand, children: [
                      if (coverUrl != null)
                        Image.network(coverUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverPlaceholder(d))
                      else
                        _coverPlaceholder(d),
                      // Scrim
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.2, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.62),
                            ],
                          ),
                        ),
                      ),
                      // Name & subtitle
                      Positioned(
                        left: 18, right: 18, bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Text(subtitle,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              // Stats row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatChip(
                        icon: Icons.grid_view_rounded,
                        label: 'أقسام',
                        value: '$categoriesCount',
                        d: d),
                    const SizedBox(width: 10),
                    _StatChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'منتجات',
                        value: '$itemsCount',
                        d: d),
                    const Spacer(),
                    // Online indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _T.accentSoft(d),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                            color: _T.accent(d).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: _T.accent(d),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('متاح الآن',
                              style: TextStyle(
                                  color: _T.accent(d),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
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
  }

  Widget _coverPlaceholder(bool d) => Container(
        color: _T.card(d),
        alignment: Alignment.center,
        child: Icon(Icons.storefront_rounded,
            color: _T.accent(d), size: 52),
      );
}

// stat chip
class _StatChip extends StatelessWidget {
  const _StatChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.d});
  final IconData icon;
  final String label, value;
  final bool d;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _T.card(d),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _T.border(d)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _T.accent(d), size: 15),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  color: _T.text(d),
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: _T.muted(d), fontSize: 11)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SEARCH BAR
// ═══════════════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  const _SearchBar(
      {required this.controller,
      required this.onChanged,
      required this.d});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool d;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.surface(d),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _T.border(d)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: d ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: _T.text(d), fontSize: 15),
        decoration: InputDecoration(
          hintText: 'ابحث عن منتج...',
          hintStyle: TextStyle(color: _T.sub(d), fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _T.accentSoft(d),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.search_rounded,
                  color: _T.accent(d), size: 16),
            ),
          ),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _T.border(d),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: _T.muted(d), size: 13),
                  ),
                ),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CATEGORY CHIP
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _T.accent(d) : _T.card(d),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: selected
                ? _T.accent(d)
                : _T.border(d),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _T.accent(d).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (d ? Colors.black87 : Colors.white)
                : _T.muted(d),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEM CARD — premium, animated
// ═══════════════════════════════════════════════════════════════════════════

class _ItemCard extends StatefulWidget {
  const _ItemCard({
    required this.item,
    required this.index,
    required this.d,
    required this.onTap,
    required this.onAddToCart,
  });
  final GuestItemListEntity item;
  final int index;
  final bool d;
  final VoidCallback onTap;
  final Future<void> Function() onAddToCart;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeScale;
  bool _isAdding = false;
  bool _added    = false;
  bool _pressed  = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: Duration(milliseconds: 500 + widget.index * 55),
        vsync: this);
    _fadeScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    Future.delayed(Duration(milliseconds: widget.index * 65),
        () => mounted ? _ctrl.forward() : null);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String? get _imageUrl {
    final img = widget.item.image?.trim();
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return img;
    return '${AppConfig.storageUrl}$img';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return FadeTransition(
      opacity: _fadeScale,
      child: ScaleTransition(
        scale: _fadeScale,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              decoration: BoxDecoration(
                color: _T.surface(d),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: _pressed
                        ? _T.accent(d).withValues(alpha: 0.5)
                        : _T.border(d),
                    width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: d ? 0.28 : 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  if (_pressed)
                    BoxShadow(
                      color: _T.accent(d).withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(21)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _imageUrl == null
                              ? Container(
                                  color: _T.card(d),
                                  child: Icon(Icons.image_outlined,
                                      color: _T.sub(d), size: 40))
                              : Hero(
                                  tag: 'item_${widget.item.id}',
                                  child: Image.network(_imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          Container(
                                              color: _T.card(d),
                                              child: Icon(
                                                  Icons
                                                      .broken_image_outlined,
                                                  color: _T.sub(d),
                                                  size: 40)))),
                          // Subtle gradient
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    _T.surface(d)
                                        .withValues(alpha: 0.6),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (widget.item.hasOffer)
                            const Positioned(
                                top: -12, left: 0,
                                child: _OfferBadge()),
                          // Zoom hint
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black
                                    .withValues(alpha: 0.28),
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                  Icons.zoom_out_map_rounded,
                                  color: Colors.white, size: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Info
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    child: Text(
                      widget.item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _T.text(d),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.3),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(10, 0, 10, 4),
                    child: _PriceWidget(
                        final_: widget.item.price,
                        original: widget.item.originalPrice,
                        hasOffer: widget.item.hasOffer,
                        d: d),
                  ),
                  // Add button
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _AddToCartBtn(
                        d: d,
                        isAdding: _isAdding,
                        added: _added,
                        onTap: _handleAdd),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAdd() async {
    if (_isAdding) return;
    HapticFeedback.lightImpact();
    setState(() => _isAdding = true);
    try {
      await widget.onAddToCart();
      if (mounted) {
        setState(() { _isAdding = false; _added = true; });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _added = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isAdding = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADD TO CART BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _AddToCartBtn extends StatelessWidget {
  const _AddToCartBtn({
    required this.d,
    required this.isAdding,
    required this.added,
    required this.onTap,
  });
  final bool d, isAdding, added;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAdding ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: 34,
        decoration: BoxDecoration(
          color: added
              ? const Color(0xFF1A8A5A).withValues(alpha: 0.9)
              : _T.accentSoft(d),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: added
                ? const Color(0xFF1A8A5A).withValues(alpha: 0.5)
                : _T.accent(d).withValues(alpha: 0.4),
          ),
        ),
        child: Center(
          child: isAdding
              ? SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _T.accent(d),
                  ))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      added
                          ? Icons.check_rounded
                          : Icons.add_shopping_cart_rounded,
                      size: 14,
                      color: added
                          ? Colors.white
                          : _T.accent(d),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      added ? 'أُضيف ✓' : 'أضف للسلة',
                      style: TextStyle(
                        color: added
                            ? Colors.white
                            : _T.accent(d),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRICE WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _PriceWidget extends StatelessWidget {
  const _PriceWidget(
      {required this.final_,
      required this.original,
      required this.hasOffer,
      required this.d});
  final PriceEntity? final_, original;
  final bool hasOffer, d;

  String _fmt(PriceEntity p) =>
      p.amount.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (final_ == null) {
      return Text('غير محدد',
          style: TextStyle(color: _T.sub(d), fontSize: 12));
    }
    final promo = hasOffer &&
        original != null &&
        final_!.amount < original!.amount;
    if (!promo) {
      return Text('\$${_fmt(final_!)}',
          style: TextStyle(
              color: _T.accent(d),
              fontWeight: FontWeight.w800,
              fontSize: 14));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('\$${_fmt(original!)}',
          style: TextStyle(
              color: _T.sub(d),
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              decorationColor: _T.sub(d),
              decorationThickness: 1.5)),
      Text('\$${_fmt(final_!)}',
          style: TextStyle(
              color: _T.warm(d),
              fontWeight: FontWeight.w800,
              fontSize: 14)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OFFER BADGE
// ═══════════════════════════════════════════════════════════════════════════

class _OfferBadge extends StatelessWidget {
  const _OfferBadge();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: CustomPaint(
        painter: _RibbonPainter(),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 11, top: 14),
            child: Transform.rotate(
              angle: -math.pi / 4,
              child: const Text('خصم',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..shader = const LinearGradient(
              colors: [Color(0xFFEE5C7F), Color(0xFFFFA06B)])
          .createShader(Rect.fromLTWH(0, 0, s.width, s.height));
    c.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(s.width * 0.82, 0)
          ..lineTo(0, s.height * 0.82)
          ..close(),
        p);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// SKELETON CARD
// ═══════════════════════════════════════════════════════════════════════════

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard(
      {required this.shimmer, required this.d, required this.delay});
  final Animation<double> shimmer;
  final bool d;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment(shimmer.value - 1, 0),
            end: Alignment(shimmer.value + 1, 0),
            colors: [
              _T.card(d),
              _T.border(d).withValues(alpha: 0.5),
              _T.card(d),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.d});
  final bool d;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: _T.accentSoft(d),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: _T.accent(d).withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.inventory_2_outlined,
              color: _T.accent(d), size: 38),
        ),
        const SizedBox(height: 18),
        Text('لا توجد منتجات',
            style: TextStyle(
                color: _T.text(d),
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('جرب تعديل البحث أو الفئة المختارة',
            style: TextStyle(color: _T.muted(d), fontSize: 13)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ACCENT BUTTON
// ═══════════════════════════════════════════════════════════════════════════

class _AccentButton extends StatelessWidget {
  const _AccentButton(
      {required this.label,
      required this.icon,
      required this.d,
      required this.onTap});
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
          color: _T.accent(d),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _T.accent(d).withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: d ? Colors.black87 : Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: d ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEM DETAIL MODAL
// ═══════════════════════════════════════════════════════════════════════════

class _ItemDetailModal extends StatelessWidget {
  const _ItemDetailModal({required this.detail});
  final GuestItemDetailEntity detail;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<ThemeState>().isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: _T.surface(d),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _T.border(d), width: 1),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _T.border(d),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _T.accentSoft(d),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _T.accent(d).withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.inventory_2_rounded,
                      color: _T.accent(d), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(detail.name,
                          style: TextStyle(
                              color: _T.text(d),
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3)),
                      if (detail.category != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _T.card(d),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: _T.border(d)),
                          ),
                          child: Text(detail.category!.name,
                              style: TextStyle(
                                  color: _T.muted(d),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              // Price hero
              _ModalPriceCard(
                final_: detail.price,
                original: detail.originalPrice,
                hasOffer: detail.hasOffer,
                offerStartsAt: detail.offerStartsAt,
                offerEndsAt: detail.offerEndsAt,
                d: d,
              ),
              const SizedBox(height: 20),
              Text('الوصف',
                  style: TextStyle(
                      color: _T.text(d),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _T.card(d),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _T.border(d)),
                ),
                child: Text(
                  detail.description.isEmpty
                      ? 'لا يوجد وصف متاح'
                      : detail.description,
                  style: TextStyle(
                      color: _T.muted(d),
                      fontSize: 14,
                      height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalPriceCard extends StatelessWidget {
  const _ModalPriceCard({
    required this.final_,
    required this.original,
    required this.hasOffer,
    required this.offerStartsAt,
    required this.offerEndsAt,
    required this.d,
  });
  final PriceEntity? final_, original;
  final bool hasOffer, d;
  final DateTime? offerStartsAt, offerEndsAt;

  String _fmt(PriceEntity p) => p.amount.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (final_ == null) return const SizedBox.shrink();
    final promo = hasOffer &&
        original != null &&
        final_!.amount < original!.amount;
    final durationTxt = _offerDurationText(offerStartsAt, offerEndsAt);

    if (!promo) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: _T.accentSoft(d),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _T.accent(d).withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(Icons.attach_money_rounded,
              color: _T.accent(d), size: 22),
          const SizedBox(width: 4),
          Text('\$${_fmt(final_!)}',
              style: TextStyle(
                  color: _T.accent(d),
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _T.warm(d).withValues(alpha: d ? 0.22 : 0.14),
            _T.warm(d).withValues(alpha: d ? 0.10 : 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _T.warm(d).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _T.warm(d).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('🔥 ',
                    style:
                        const TextStyle(fontSize: 12)),
                Text('خصم',
                    style: TextStyle(
                        color: _T.warm(d),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text('\$${_fmt(original!)}',
              style: TextStyle(
                  color: _T.muted(d),
                  fontSize: 14,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _T.muted(d),
                  decorationThickness: 2)),
          const SizedBox(height: 2),
          Text('\$${_fmt(final_!)}',
              style: TextStyle(
                  color: _T.warm(d),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          if (durationTxt != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule_rounded,
                  size: 13, color: _T.muted(d)),
              const SizedBox(width: 4),
              Text(durationTxt,
                  style: TextStyle(
                      color: _T.muted(d),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIRM DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.onConfirm,
    required this.onCancel,
  });
  final String title, message, confirmText, cancelText;
  final VoidCallback onConfirm, onCancel;

  @override
  Widget build(BuildContext context) {
    final d = context.watch<ThemeState>().isDarkMode;

    return Dialog(
      backgroundColor: _T.surface(d),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _T.error(d).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _T.error(d).withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: _T.error(d), size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    color: _T.text(d),
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _T.muted(d),
                    fontSize: 13,
                    height: 1.5)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _T.card(d),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _T.border(d)),
                    ),
                    child: Center(
                      child: Text(cancelText,
                          style: TextStyle(
                              color: _T.muted(d),
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _T.error(d),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(confirmText,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

String? _offerDurationText(DateTime? startsAt, DateTime? endsAt) {
  if (startsAt == null && endsAt == null) return null;
  final now = DateTime.now();
  String fmtDate(DateTime v) =>
      '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}';
  if (endsAt != null) {
    final diff = endsAt.difference(now).inDays;
    if (diff < 0) return 'انتهى العرض';
    if (diff == 0) return 'ينتهي اليوم';
    return 'متبقي $diff أيام';
  }
  if (startsAt != null) return 'يبدأ ${fmtDate(startsAt)}';
  return null;
}