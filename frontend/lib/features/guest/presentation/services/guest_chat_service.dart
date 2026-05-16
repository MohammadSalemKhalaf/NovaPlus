import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';

class GuestConversation {
  const GuestConversation({
    required this.id,
    required this.tenantId,
    required this.endUserId,
    required this.status,
    required this.contextType,
    required this.lastMessagePreview,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
  });

  final int id;
  final int tenantId;
  final int endUserId;
  final String status;
  final String contextType;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory GuestConversation.fromJson(Map<String, dynamic> json) {
    return GuestConversation(
      id: _readInt(json['id']),
      tenantId: _readInt(json['tenant_id']),
      endUserId: _readInt(json['end_user_id']),
      status: json['status']?.toString() ?? 'active',
      contextType: json['context_type']?.toString() ?? 'general',
      lastMessagePreview: json['last_message_preview']?.toString(),
      lastMessageAt: _readDateTime(json['last_message_at']),
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  static int _readInt(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

  static DateTime? _readDateTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}

class GuestChatMessage {
  const GuestChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.messageType,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.senderName,
    this.mediaUrl,
    this.mediaType,
    this.replyToMessageId,
    this.metadata,
    this.readAt,
  });

  final int id;
  final int conversationId;
  final String senderType;
  final String? senderName;
  final String messageType;
  final String body;
  final String? mediaUrl;
  final String? mediaType;
  final Map<String, dynamic>? metadata;
  final int? replyToMessageId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  factory GuestChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    final senderName = sender is Map ? sender['name']?.toString() : null;

    return GuestChatMessage(
      id: _readInt(json['id']),
      conversationId: _readInt(json['conversation_id']),
      senderType: json['sender_type']?.toString() ?? 'end_user',
      senderName: senderName,
      messageType: json['message_type']?.toString() ?? 'text',
      body: json['body']?.toString() ?? '',
      mediaUrl: json['media_url']?.toString(),
      mediaType: json['media_type']?.toString(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
      replyToMessageId: _readNullableInt(json['reply_to_message_id']),
      isRead: _readBool(json['is_read']),
      readAt: _readDateTime(json['read_at']),
      createdAt: _readDateTime(json['created_at']),
    );
  }

  static int _readInt(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

  static int? _readNullableInt(Object? value) {
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed == 0 ? null : parsed;
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1';
  }

  static DateTime? _readDateTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }
}

class GuestChatService {
  GuestChatService({required ApiClient apiClient})
      : _apiClient = apiClient,
        _firebaseDio = Dio(
          BaseOptions(
            baseUrl: AppConfig.firebaseRealtimeDatabaseUrl.endsWith('/')
                ? AppConfig.firebaseRealtimeDatabaseUrl
                : '${AppConfig.firebaseRealtimeDatabaseUrl}/',
            responseType: ResponseType.json,
          ),
        );

  final ApiClient _apiClient;
  final Dio _firebaseDio;

  Future<GuestConversation> startConversation(int tenantId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/enduser/conversations/start',
      data: <String, dynamic>{'tenant_id': tenantId},
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Empty conversation response');
    }

    final payload = data['data'];
    if (payload is! Map) {
      throw Exception('Invalid conversation response');
    }

    final conversation = payload['conversation'];
    if (conversation is! Map) {
      throw Exception('Conversation payload not found');
    }

    return GuestConversation.fromJson(Map<String, dynamic>.from(conversation));
  }

  Future<List<GuestChatMessage>> listMessages(int conversationId) async {
    final realtimeMessages = await _loadRealtimeMessages(conversationId);
    if (realtimeMessages.isNotEmpty) {
      return realtimeMessages;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/conversations/$conversationId/messages',
      queryParameters: <String, dynamic>{'per_page': 50},
    );

    final data = response.data;
    if (data == null) {
      return const <GuestChatMessage>[];
    }

    final rawItems = _extractItems(data['data']);
    return rawItems
        .map((item) => GuestChatMessage.fromJson(item))
        .toList(growable: false);
  }

  Future<void> sendTextMessage({
    required int conversationId,
    required String body,
    int? replyToMessageId,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/enduser/messages',
      data: <String, dynamic>{
        'conversation_id': conversationId,
        'body': body,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
      },
    );
  }

  Future<void> markAsRead(int conversationId) async {
    await _apiClient.post<Map<String, dynamic>>('/conversations/$conversationId/read');
  }

  Future<List<GuestChatMessage>> _loadRealtimeMessages(int conversationId) async {
    if (AppConfig.firebaseRealtimeDatabaseUrl.trim().isEmpty) {
      return const <GuestChatMessage>[];
    }

    try {
      final response = await _firebaseDio.get<dynamic>('conversations/$conversationId/messages.json');
      final data = response.data;
      if (data is! Map) {
        return const <GuestChatMessage>[];
      }

      final messages = data.entries
          .where((entry) => entry.value is Map)
          .map((entry) {
            final payload = Map<String, dynamic>.from(entry.value as Map);
            payload.putIfAbsent('id', () => int.tryParse(entry.key.toString()) ?? 0);
            return GuestChatMessage.fromJson(payload);
          })
          .toList(growable: false);

      messages.sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });

      return messages;
    } catch (_) {
      return const <GuestChatMessage>[];
    }
  }

  List<Map<String, dynamic>> _extractItems(Object? data) {
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false);
    }

    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }
}