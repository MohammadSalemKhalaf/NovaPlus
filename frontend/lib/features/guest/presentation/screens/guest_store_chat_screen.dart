import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/notifications/chat_presence.dart';
import '../../../../core/notifications/enduser_chat_notification_watcher.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/image_helper.dart';
import '../../domain/entities/guest_entities.dart';
import '../services/guest_chat_service.dart';
import '../services/guest_notifications_service.dart';

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

class GuestStoreChatScreen extends StatefulWidget {
  const GuestStoreChatScreen({super.key, required this.store})
      : initialConversationId = null,
        chatTitle = null;

  const GuestStoreChatScreen.fromConversation({
    super.key,
    required this.initialConversationId,
    this.chatTitle,
  }) : store = null;

  final GuestStoreEntity? store;
  final int? initialConversationId;
  final String? chatTitle;

  @override
  State<GuestStoreChatScreen> createState() => _GuestStoreChatScreenState();
}

class _GuestStoreChatScreenState extends State<GuestStoreChatScreen> {
  late final GuestChatService _service;
  late final GuestNotificationsService _notificationsService;
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  Timer? _refreshTimer;

  GuestConversation? _conversation;
  int? _activeConversationId;
  List<GuestChatMessage> _messages = const <GuestChatMessage>[];
  bool _isBootstrapping = true;
  bool _isSending = false;
  String? _errorMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    ChatPresence.isGuestChatOpen.value = true;
    final apiClient = ApiClient(secureStorage: SecureStorage());
    _service = GuestChatService(apiClient: apiClient);
    _notificationsService = GuestNotificationsService(apiClient: apiClient);
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _bootstrap();
  }

  @override
  void dispose() {
    ChatPresence.isGuestChatOpen.value = false;
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isBootstrapping = true;
      _errorMessage = null;
    });

    try {
      GuestConversation? conversation;
      final seededConversationId = widget.initialConversationId;

      if (seededConversationId != null && seededConversationId > 0) {
        _activeConversationId = seededConversationId;
      } else {
        final store = widget.store;
        if (store == null) {
          throw Exception('Store context is missing.');
        }

        conversation = await _service.startConversation(store.id);
        _activeConversationId = conversation.id;
      }

      final messages = await _service.listMessages(_activeConversationId!);

      if (!mounted) return;

      setState(() {
        _conversation = conversation;
        _messages = messages;
        _isBootstrapping = false;
      });

      await _service.markAsRead(_activeConversationId!);
      await _notificationsService.markAllAsRead();
      await EndUserChatNotificationWatcher.instance.refreshNow(allowNotify: false);
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || _activeConversationId == null) return;
        _refreshMessages(silent: true);
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isBootstrapping = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshMessages({bool silent = false}) async {
    final conversationId = _activeConversationId;
    if (conversationId == null) return;

    try {
      final messages = await _service.listMessages(conversationId);
      if (!mounted) return;

      setState(() {
        _messages = messages;
        if (!silent) _errorMessage = null;
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => _errorMessage = 'Unable to refresh messages.');
    }
  }

  Future<void> _sendMessage() async {
    final conversationId = _activeConversationId;
    if (conversationId == null) return;

    final body = _messageController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _service.sendTextMessage(conversationId: conversationId, body: body);
      await _service.markAsRead(conversationId);
      await _notificationsService.markAllAsRead();
      await EndUserChatNotificationWatcher.instance.refreshNow(allowNotify: false);
      await _refreshMessages();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $error'),
            backgroundColor: const Color(0xFFB00020),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _messageAuthorLabel(GuestChatMessage message) {
    if (message.senderType == 'end_user') {
      return 'You';
    }

    final senderName = message.senderName?.trim();
    if (senderName != null && senderName.isNotEmpty) {
      return senderName;
    }

    return 'Store';
  }

  @override
  Widget build(BuildContext context) {
    final d = _isDark;
    final chatTitle = widget.store?.name ?? widget.chatTitle ?? 'Chat';
    final storeImageUrl = widget.store == null ? null : ImageHelper.build(widget.store!.image);

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
                  _buildHeader(d, chatTitle, storeImageUrl),
                  Expanded(
                    child: _isBootstrapping
                        ? _buildLoadingState(d)
                        : _errorMessage != null && _conversation == null
                            ? _buildErrorState(d)
                            : Column(
                                children: [
                                  Expanded(
                                    child: RefreshIndicator(
                                      onRefresh: _refreshMessages,
                                      color: _DT.accent(d),
                                      backgroundColor: _DT.glass(d),
                                      child: ListView.builder(
                                        controller: _scrollController,
                                        physics: const AlwaysScrollableScrollPhysics(
                                          parent: BouncingScrollPhysics(),
                                        ),
                                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                                        itemCount: _messages.length + 1,
                                        itemBuilder: (context, index) {
                                          if (index == 0) {
                                            return _buildConversationBanner(d);
                                          }

                                          final message = _messages[index - 1];
                                          final isOwnMessage = message.senderType == 'end_user';

                                          return _ChatBubble(
                                            message: message,
                                            isOwnMessage: isOwnMessage,
                                            authorLabel: _messageAuthorLabel(message),
                                            darkMode: d,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  _buildComposer(d),
                                ],
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

  Widget _buildHeader(bool d, String chatTitle, String? storeImageUrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _GlassIconButton(
            d: d,
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_rounded, color: _DT.text(d), size: 20),
          ),
          const SizedBox(width: 10),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _DT.glass(d),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _DT.glassBorder(d)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: storeImageUrl != null
                  ? Image.network(
                      storeImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.storefront_rounded,
                        color: _DT.accent(d),
                        size: 22,
                      ),
                    )
                  : Icon(Icons.storefront_rounded, color: _DT.accent(d), size: 22),
            ),
          ),
          const SizedBox(width: 12),
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
                  chatTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _DT.text(d),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Realtime chat with the store',
                  style: TextStyle(
                    color: _DT.muted(d),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          _GlassIconButton(
            d: d,
            onTap: () async {
              if (_activeConversationId != null) {
                await _refreshMessages();
              }
            },
            child: Icon(Icons.refresh_rounded, color: _DT.text(d), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool d) {
    return Center(
      child: _GlassCard(
        d: d,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                color: _DT.accent(d),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Opening chat...',
              style: TextStyle(
                color: _DT.text(d),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationBanner(bool d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DT.glass(d),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DT.glassBorder(d)),
        boxShadow: [
          BoxShadow(
            color: _DT.shadowCard(d),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _DT.accentSoft(d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bolt_rounded, color: _DT.accent(d), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Messages are synced with Firebase Realtime Database when available.',
              style: TextStyle(
                color: _DT.text(d),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(bool d) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: _DT.bgBase(d),
          border: Border(
            top: BorderSide(color: _DT.border(d).withValues(alpha: 0.6)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: _DT.text(d)),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: TextStyle(color: _DT.muted(d)),
                  filled: true,
                  fillColor: _DT.glass(d),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: _DT.glassBorder(d)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: _DT.accent(d)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _DT.accent(d),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _DT.accentGlow(d),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSending
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: d ? const Color(0xFF0B0C10) : Colors.white,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: d ? const Color(0xFF0B0C10) : Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool d) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _GlassCard(
          d: d,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded, color: _DT.accent(d), size: 54),
              const SizedBox(height: 16),
              Text(
                'Unable to open chat',
                style: TextStyle(
                  color: _DT.text(d),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _DT.muted(d), fontSize: 13),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _bootstrap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: _DT.accent(d),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: d ? const Color(0xFF0B0C10) : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isOwnMessage,
    required this.authorLabel,
    required this.darkMode,
  });

  final GuestChatMessage message;
  final bool isOwnMessage;
  final String authorLabel;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final alignment = isOwnMessage ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isOwnMessage ? _DT.accent(darkMode) : _DT.glass(darkMode);
    final borderColor = isOwnMessage ? Colors.transparent : _DT.glassBorder(darkMode);
    final messageColor = isOwnMessage ? (darkMode ? const Color(0xFF0B0C10) : Colors.white) : _DT.text(darkMode);
    final secondaryColor = isOwnMessage ? (darkMode ? const Color(0xFF0B0C10) : Colors.white).withValues(alpha: 0.72) : _DT.muted(darkMode);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isOwnMessage ? 18 : 4),
            bottomRight: Radius.circular(isOwnMessage ? 4 : 18),
          ),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (isOwnMessage)
              BoxShadow(
                color: _DT.accentGlow(darkMode),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: _DT.shadowCard(darkMode),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authorLabel,
              style: TextStyle(
                color: secondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message.body,
              style: TextStyle(
                color: messageColor,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                message.mediaUrl!,
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              message.createdAt?.toLocal().toString().substring(0, 16) ?? '',
              style: TextStyle(
                color: secondaryColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.d, required this.child});

  final bool d;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _DT.glass(d),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _DT.glassBorder(d), width: 1),
            boxShadow: [
              BoxShadow(
                color: _DT.shadowCard(d),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
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

    _drawOrb(canvas, center: Offset(size.width * 0.82, size.height * 0.08), radius: size.width * 0.52, color: _DT.orb1(d));
    _drawOrb(canvas, center: Offset(size.width * 0.1, size.height * 0.78), radius: size.width * 0.45, color: _DT.orb2(d));
    _drawOrb(canvas, center: Offset(size.width * 0.55, size.height * 0.42), radius: size.width * 0.3, color: _DT.orb3(d));

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
