import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../favorites/presentation/favorites_cubit.dart';
import '../../data/datasources/guest_remote_data_source.dart';
import '../../data/repositories/guest_repository_impl.dart';
import '../../domain/entities/guest_entities.dart';
import '../../domain/repositories/guest_repository.dart';
import '../../domain/usecases/list_guest_stores_use_case.dart';
import 'guest_store_details_screen.dart';

class _DT {
  static Color accent(bool d) => d ? const Color(0xFF5CE1B0) : const Color(0xFF00A878);
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

  static Color shadowCard(bool d) => d ? Colors.black.withValues(alpha: 0.40) : Colors.black.withValues(alpha: 0.06);
}

class GuestScanQrScreen extends StatefulWidget {
  const GuestScanQrScreen({
    super.key,
    this.isActive = false,
  });

  final bool isActive;

  @override
  State<GuestScanQrScreen> createState() => _GuestScanQrScreenState();
}

class _GuestScanQrScreenState extends State<GuestScanQrScreen> {
  late final ListGuestStoresUseCase _listGuestStoresUseCase;
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    autoStart: false,
  );
  final TextEditingController _manualInputController = TextEditingController();

  bool _isHandlingScan = false;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();

    final storage = SecureStorage();
    final apiClient = ApiClient(secureStorage: storage);
    final remoteDataSource = GuestRemoteDataSource(apiClient: apiClient);
    final GuestRepository repository =
        GuestRepositoryImpl(remoteDataSource: remoteDataSource);
    _listGuestStoresUseCase = ListGuestStoresUseCase(repository);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.isActive) {
        return;
      }
      await _scannerController.start();
    });
  }

  @override
  void didUpdateWidget(covariant GuestScanQrScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) {
      return;
    }
    if (widget.isActive) {
      _scannerController.start();
    } else {
      _scannerController.stop();
    }
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _openFromRawValue(String raw, {bool isManual = false}) async {
    final value = raw.trim();
    if (isManual && value.isEmpty) {
      _showMessage('Please enter a store QR link or slug.');
      return;
    }

    final ref = _StoreScanRef.fromRaw(value);
    if (ref == null) {
      _showMessage('Invalid store reference.');
      return;
    }

    if (ref.slug != null && ref.slug!.isNotEmpty) {
      await _openStore(
        GuestStoreEntity(
          id: ref.tenantId ?? 0,
          name: ref.slug!,
          slug: ref.slug!,
        ),
      );
      return;
    }

    if (ref.tenantId != null) {
      final stores = await _listGuestStoresUseCase(perPage: 100);
      GuestStoreEntity? matched;
      for (final store in stores) {
        if (store.id == ref.tenantId) {
          matched = store;
          break;
        }
      }

      if (matched == null) {
        _showMessage('Store not found for provided ID.');
        return;
      }

      await _openStore(matched);
      return;
    }

    _showMessage('Unable to resolve store reference.');
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isHandlingScan) {
      return;
    }

    final raw = capture.barcodes.isNotEmpty
        ? (capture.barcodes.first.rawValue ?? '').trim()
        : '';
    if (raw.isEmpty) {
      return;
    }

    _isHandlingScan = true;
    await _scannerController.stop();

    try {
      await _openFromRawValue(raw);
    } catch (error) {
      _showMessage('QR scan failed: $error');
    } finally {
      _isHandlingScan = false;
      if (mounted) {
        await _scannerController.start();
      }
    }
  }

  Future<void> _openStore(GuestStoreEntity store) async {
    if (!mounted) {
      return;
    }

    final favoritesCubit = context.read<FavoritesCubit>();

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<FavoritesCubit>.value(
          value: favoritesCubit,
          child: GuestStoreDetailsScreen(initialStore: store),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
            _AtmosphericBg(d: d),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(d),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _DT.glass(d),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: _DT.glassBorder(d)),
                              boxShadow: [
                                BoxShadow(
                                  color: _DT.shadowCard(d),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      MobileScanner(
                                        controller: _scannerController,
                                        onDetect: _onDetect,
                                      ),
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.black.withValues(alpha: d ? 0.22 : 0.16),
                                                width: 999,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          margin: const EdgeInsets.all(14),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: _DT.glass(d),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: _DT.glassBorder(d)),
                                          ),
                                          child: Text(
                                            'Scan a store QR to open it directly',
                                            style: TextStyle(color: _DT.text(d), fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                  decoration: BoxDecoration(
                                    color: _DT.glass(d),
                                    border: Border(top: BorderSide(color: _DT.glassBorder(d))),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: _manualInputController,
                                        style: TextStyle(color: _DT.text(d)),
                                        decoration: InputDecoration(
                                          hintText: 'Paste store QR link or slug',
                                          hintStyle: TextStyle(color: _DT.muted(d)),
                                          filled: true,
                                          fillColor: d
                                              ? Colors.white.withValues(alpha: 0.04)
                                              : Colors.white.withValues(alpha: 0.85),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: _DT.glassBorder(d)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: _DT.glassBorder(d)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: _DT.accent(d)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 44,
                                        child: ElevatedButton(
                                          onPressed: () => _openFromRawValue(
                                            _manualInputController.text,
                                            isManual: true,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _DT.accent(d),
                                            foregroundColor: d ? const Color(0xFF0B0C10) : Colors.white,
                                          ),
                                          child: const Text('Open Store'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildHeader(bool d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GlassIconButton(
            d: d,
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(Icons.arrow_back_rounded, color: _DT.text(d), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            blurRadius: 7,
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
                ),
                const SizedBox(height: 6),
                Text(
                  'مسح QR',
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
                  'Scan QR',
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
            onTap: () {
              if (widget.isActive) {
                _scannerController.stop();
                _scannerController.start();
              }
            },
            child: Icon(Icons.qr_code_scanner_rounded, color: _DT.text(d), size: 20),
          ),
        ],
      ),
    );
  }
}

class _AtmosphericBg extends StatelessWidget {
  const _AtmosphericBg({required this.d});

  final bool d;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: CustomPaint(
        painter: _BgPainter(d: d, size: size),
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  const _BgPainter({required this.d, required this.size});

  final bool d;
  final Size size;

  @override
  void paint(Canvas canvas, Size _) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _DT.bgBase(d),
    );

    _drawOrb(
      canvas,
      center: Offset(size.width * 0.82, size.height * 0.08),
      radius: size.width * 0.52,
      color: _DT.orb1(d),
    );
    _drawOrb(
      canvas,
      center: Offset(size.width * 0.1, size.height * 0.78),
      radius: size.width * 0.45,
      color: _DT.orb2(d),
    );
    _drawOrb(
      canvas,
      center: Offset(size.width * 0.55, size.height * 0.42),
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
  bool shouldRepaint(_BgPainter oldDelegate) => oldDelegate.d != d;
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.d, required this.onTap, required this.child});

  final bool d;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
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
      ),
    );
  }
}

class _StoreScanRef {
  const _StoreScanRef({this.slug, this.tenantId});

  final String? slug;
  final int? tenantId;

  static _StoreScanRef? fromRaw(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final jsonRef = _fromJson(value);
    if (jsonRef != null) {
      return jsonRef;
    }

    final uriRef = _fromUri(value);
    if (uriRef != null) {
      return uriRef;
    }

    final keyValueRef = _fromKeyValue(value);
    if (keyValueRef != null) {
      return keyValueRef;
    }

    final tenantId = int.tryParse(value);
    if (tenantId != null && tenantId > 0) {
      return _StoreScanRef(tenantId: tenantId);
    }

    if (_looksLikeSlug(value)) {
      return _StoreScanRef(slug: value);
    }

    return null;
  }

  static _StoreScanRef? _fromJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);
      final slug = _firstString(map, const [
        'slug',
        'store_slug',
        'tenant_slug',
      ]);
      final tenantId = _firstInt(map, const [
        'tenant_id',
        'store_id',
        'id',
      ]);

      if (slug == null && tenantId == null) {
        return null;
      }
      return _StoreScanRef(slug: slug, tenantId: tenantId);
    } catch (_) {
      return null;
    }
  }

  static _StoreScanRef? _fromUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final querySlug = uri.queryParameters['slug']?.trim();
    final queryTenantId = int.tryParse(uri.queryParameters['tenant_id'] ?? '');
    if (querySlug != null && querySlug.isNotEmpty) {
      return _StoreScanRef(slug: querySlug, tenantId: queryTenantId);
    }
    if (queryTenantId != null && queryTenantId > 0) {
      return _StoreScanRef(tenantId: queryTenantId);
    }

    final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.isEmpty) {
      return null;
    }

    final storeIndex = segments.indexOf('store');
    if (storeIndex >= 0 && storeIndex + 1 < segments.length) {
      final slug = segments[storeIndex + 1].trim();
      if (_looksLikeSlug(slug)) {
        return _StoreScanRef(slug: slug);
      }
    }

    final last = segments.last.trim();
    final asId = int.tryParse(last);
    if (asId != null && asId > 0) {
      return _StoreScanRef(tenantId: asId);
    }
    if (_looksLikeSlug(last)) {
      return _StoreScanRef(slug: last);
    }

    return null;
  }

  static _StoreScanRef? _fromKeyValue(String value) {
    final slugMatch = RegExp(r'(?:^|[?&\s])(?:slug|store_slug|tenant_slug)=([a-zA-Z0-9_-]+)')
        .firstMatch(value);
    final idMatch = RegExp(r'(?:^|[?&\s])(?:tenant_id|store_id|id)=(\d+)').firstMatch(value);

    final slug = slugMatch?.group(1);
    final tenantId = idMatch == null ? null : int.tryParse(idMatch.group(1) ?? '');

    if (slug == null && tenantId == null) {
      return null;
    }

    return _StoreScanRef(slug: slug, tenantId: tenantId);
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int && value > 0) {
        return value;
      }
      final parsed = int.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  static bool _looksLikeSlug(String value) {
    return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{1,}$').hasMatch(value);
  }
}
