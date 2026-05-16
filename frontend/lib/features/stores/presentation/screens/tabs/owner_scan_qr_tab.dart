import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/config/app_config.dart';
import '../../../../../core/storage/secure_storage.dart';
import '../../../../categories/data/datasources/stores_remote_data_source.dart';
import '../../../../categories/data/repositories/stores_repository_impl.dart';
import '../../../../categories/domain/repositories/stores_repository.dart';
import '../store_details_screen.dart';
import '../../theme/owner_theme.dart';

class OwnerScanQrTab extends StatefulWidget {
  const OwnerScanQrTab({super.key});

  @override
  State<OwnerScanQrTab> createState() => _OwnerScanQrTabState();
}

class _OwnerScanQrTabState extends State<OwnerScanQrTab> {
  late final SecureStorage _secureStorage;
  late final StoresRepository _storesRepository;

  bool _isProcessing = false;
  String _tenantName = 'My Store';
  String _tenantSlug = '';
  final TextEditingController _testQrController = TextEditingController();

  // TODO: REMOVE IN PRODUCTION
  static const bool _enableAutoTestQrInDebug = false;

  @override
  void initState() {
    super.initState();
    _secureStorage = SecureStorage();
    final apiClient = ApiClient(secureStorage: _secureStorage);
    _storesRepository = StoresRepositoryImpl(
      remoteDataSource: StoresRemoteDataSource(apiClient: apiClient),
    );
    _loadOwnerStoreContext();

    if (kDebugMode && _enableAutoTestQrInDebug) {
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (!mounted) {
          return;
        }
        _handleScan('http://10.0.2.2:8000/store/novaplus-demo');
      });
    }
  }

  @override
  void dispose() {
    _testQrController.dispose();
    super.dispose();
  }

  String storePublicUrl(String slug) {
    return AppConfig.storePublicUrl(slug);
  }

  Future<void> _loadOwnerStoreContext() async {
    final tenantId = (await _secureStorage.getTenantId() ?? '').trim();
    final rawTenants = await _secureStorage.getUserTenants();

    String resolvedName = 'My Store';
    String resolvedSlug = '';

    if (rawTenants != null && rawTenants.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTenants);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map) {
              continue;
            }

            final map = Map<String, dynamic>.from(entry);
            final id = (map['id']?.toString() ?? '').trim();
            if (tenantId.isNotEmpty && id != tenantId) {
              continue;
            }

            final name = (map['name']?.toString() ?? '').trim();
            final slug = (map['slug']?.toString() ?? '').trim();

            if (name.isNotEmpty) {
              resolvedName = name;
            }
            if (slug.isNotEmpty) {
              resolvedSlug = slug;
            }

            if (tenantId.isNotEmpty && id == tenantId) {
              break;
            }
          }
        }
      } catch (_) {
        // Ignore parse failure and keep defaults.
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _tenantName = resolvedName;
      _tenantSlug = resolvedSlug;
    });
  }

  String? _extractTenantSlug(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final slugPattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
    if (slugPattern.hasMatch(trimmed.toLowerCase())) {
      return trimmed.toLowerCase();
    }

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      uri = null;
    }

    if (uri == null) {
      return trimmed.toLowerCase();
    }

    final segments = uri.pathSegments
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    if (segments.isEmpty) {
      return null;
    }

    for (var i = 0; i < segments.length; i++) {
      if (segments[i].toLowerCase() == 'store' && i + 1 < segments.length) {
        final slug = segments[i + 1].toLowerCase();
        if (slug.isNotEmpty && slugPattern.hasMatch(slug)) {
          return slug;
        }
      }
    }

    if (segments.length == 1) {
      final slug = segments.first.toLowerCase();
      if (slug.isNotEmpty && slugPattern.hasMatch(slug)) {
        return slug;
      }
    }

    return null;
  }

  Future<void> _resetScanner() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    await Future<void>.delayed(const Duration(seconds: 1));
    await _resetScanner();
  }

  Future<void> _copyStoreLink() async {
    final url = storePublicUrl(_tenantSlug);
    if (_tenantSlug.isEmpty || url.isEmpty) {
      await _showError('Store URL unavailable');
      return;
    }

    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Store link copied.')));
  }

  Future<void> _shareStoreLink() async {
    final url = storePublicUrl(_tenantSlug);
    if (_tenantSlug.isEmpty || url.isEmpty) {
      await _showError('Store URL unavailable');
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: 'Visit $_tenantName: $url',
        subject: 'NovaPlus Store Link',
      ),
    );
  }

  Future<void> _openStoreBySlug(String slug) async {
    try {
      final matched = await _storesRepository.getStoreBySlug(slug);

      if (matched == null) {
        await _showError('Store not found');
        return;
      }

      if (!mounted) return;

      final currentTheme = Theme.of(context);
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => Theme(
            data: currentTheme,
            child: StoreDetailsScreen(store: matched),
          ),
        ),
      );
      await _resetScanner();
    } catch (_) {
      await _showError('Store not found');
    }
  }

  Future<void> _handleScan(String raw) async {
    if (_isProcessing) {
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    } else {
      _isProcessing = true;
    }
    // ignore: avoid_print
    print('SCANNED VALUE: $raw');
    // ignore: avoid_print
    print('QR RAW: $raw');
    // ignore: avoid_print
    print('TEST QR RAW: $raw');

    final slug = _extractTenantSlug(raw);
    // ignore: avoid_print
    print('EXTRACTED SLUG: $slug');
    // ignore: avoid_print
    print('TEST SLUG: $slug');

    if (slug == null) {
      await _showError('Invalid QR code');
      return;
    }

    await _openStoreBySlug(slug);
  }

  Future<void> _runTestQr(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) {
      await _showError('Invalid QR code');
      return;
    }

    await _handleScan(value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);
    final url = storePublicUrl(_tenantSlug);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isProcessing)
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    CircularProgressIndicator(color: palette.primary),
                    SizedBox(height: 10),
                    Text(
                      'Opening store...',
                      style: TextStyle(
                        color: palette.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'My Store QR',
              style: TextStyle(
                color: palette.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  Text(
                    _tenantName,
                    style: TextStyle(
                      color: palette.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_tenantSlug.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: url,
                        size: 180,
                        backgroundColor: palette.surface,
                        version: QrVersions.auto,
                      ),
                    )
                  else
                    Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No store slug found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.onSurfaceMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    url.isEmpty ? 'Store URL unavailable' : url,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.onSurfaceMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _copyStoreLink,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: palette.border),
                            foregroundColor: palette.onSurface,
                          ),
                          child: const Text('Copy Link'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _shareStoreLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer Test Mode',
                    style: TextStyle(
                      color: palette.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _runTestQr(
                      'http://10.0.2.2:8000/store/novaplus-demo',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.secondary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('TEST QR'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _testQrController,
                    style: TextStyle(color: palette.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Paste QR URL or slug',
                      hintStyle: TextStyle(color: palette.onSurfaceMuted),
                      filled: true,
                      fillColor: palette.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _runTestQr(_testQrController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Custom QR'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '// TODO: REMOVE IN PRODUCTION',
                    style: TextStyle(
                      color: Color(0xFF8C8CA8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
