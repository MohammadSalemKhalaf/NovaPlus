import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../../core/api/api_client.dart';
import '../../../../../core/storage/secure_storage.dart';
import '../../services/owner_chat_service.dart';
import '../../services/owner_notifications_service.dart';
import '../../theme/owner_theme.dart';

class OwnerChatTab extends StatefulWidget {
  const OwnerChatTab({
    super.key,
    required this.onUnauthorized,
  });

  final Future<void> Function() onUnauthorized;

  @override
  State<OwnerChatTab> createState() => _OwnerChatTabState();
}

class _OwnerChatTabState extends State<OwnerChatTab> {
  late final OwnerChatService _service;
  Timer? _refreshTimer;
  List<OwnerConversationNotification> _conversations = const <OwnerConversationNotification>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = OwnerChatService(apiClient: ApiClient(secureStorage: SecureStorage()));
    _loadConversations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) {
        return;
      }
      _loadConversations(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final conversations = await _service.listConversations();
      if (!mounted) {
        return;
      }

      setState(() {
        _conversations = conversations;
        _isLoading = false;
        if (!silent) {
          _errorMessage = null;
        }
      });
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
        await widget.onUnauthorized();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = 'Unable to load conversations';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = 'Unable to load conversations';
        }
      });
    }
  }

  Future<void> _openConversation(OwnerConversationNotification conversation) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OwnerConversationScreen(
          conversation: conversation,
          service: _service,
        ),
      ),
    );

    if (changed == true) {
      await _loadConversations(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(color: palette.onSurfaceMuted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _conversations.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Chats',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: palette.onSurface,
                ),
              ),
            );
          }

          final conversation = _conversations[index - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _openConversation(conversation),
              leading: CircleAvatar(
                backgroundColor: palette.primarySoft,
                child: Text(
                  conversation.endUserName.isNotEmpty
                      ? conversation.endUserName.characters.first.toUpperCase()
                      : 'G',
                  style: TextStyle(color: palette.primary, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(
                conversation.endUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                conversation.lastMessagePreview?.trim().isNotEmpty == true
                    ? conversation.lastMessagePreview!.trim()
                    : 'Open conversation',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: conversation.unreadCount > 0
                  ? CircleAvatar(
                      radius: 12,
                      backgroundColor: palette.error,
                      child: Text(
                        conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}

class OwnerConversationScreen extends StatefulWidget {
  const OwnerConversationScreen({
    super.key,
    required this.conversation,
    required this.service,
  });

  final OwnerConversationNotification conversation;
  final OwnerChatService service;

  @override
  State<OwnerConversationScreen> createState() => _OwnerConversationScreenState();
}

class _OwnerConversationScreenState extends State<OwnerConversationScreen> {
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  Timer? _refreshTimer;

  List<OwnerChatMessage> _messages = const <OwnerChatMessage>[];
  bool _isLoading = true;
  bool _isSending = false;
  bool _didMarkAsRead = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) {
        return;
      }
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final messages = await widget.service.listMessages(widget.conversation.conversationId);
      await widget.service.markConversationAsRead(widget.conversation.conversationId);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
        _didMarkAsRead = true;
        if (!silent) {
          _errorMessage = null;
        }
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = 'Unable to load messages';
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await widget.service.sendTextMessage(
        conversationId: widget.conversation.conversationId,
        body: body,
      );
      await _loadMessages(silent: true);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _senderLabel(OwnerChatMessage message) {
    if (message.senderType == 'owner') {
      return 'You';
    }
    return message.senderName?.trim().isNotEmpty == true
        ? message.senderName!.trim()
        : widget.conversation.endUserName;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OwnerTheme.palette(context);

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_didMarkAsRead);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(_didMarkAsRead),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(widget.conversation.endUserName),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, style: TextStyle(color: palette.onSurfaceMuted)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadMessages,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadMessages,
                          child: ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isOwner = message.senderType == 'owner';

                              return Align(
                                alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                                  decoration: BoxDecoration(
                                    color: isOwner ? palette.primary : palette.surfaceElevated,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _senderLabel(message),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isOwner ? Colors.white70 : palette.onSurfaceMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message.body,
                                        style: TextStyle(
                                          color: isOwner ? Colors.white : palette.onSurface,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    hintText: 'Write a message...',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _isSending ? null : _sendMessage,
                                icon: _isSending
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
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
}
