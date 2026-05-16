import '../../../../core/api/api_client.dart';
import 'owner_notifications_service.dart';

class OwnerChatMessage {
  const OwnerChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.messageType,
    required this.body,
    required this.isRead,
    this.senderName,
    this.createdAt,
  });

  final int id;
  final int conversationId;
  final String senderType;
  final String? senderName;
  final String messageType;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  factory OwnerChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    final senderName = sender is Map ? sender['name']?.toString() : null;

    return OwnerChatMessage(
      id: _readInt(json['id']),
      conversationId: _readInt(json['conversation_id']),
      senderType: json['sender_type']?.toString() ?? 'end_user',
      senderName: senderName,
      messageType: json['message_type']?.toString() ?? 'text',
      body: json['body']?.toString() ?? '',
      isRead: _readBool(json['is_read']),
      createdAt: _readDateTime(json['created_at']),
    );
  }

  static int _readInt(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

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

class OwnerChatService {
  OwnerChatService({required ApiClient apiClient})
      : _apiClient = apiClient,
        _ownerNotificationsService = OwnerNotificationsService(apiClient: apiClient);

  final ApiClient _apiClient;
  final OwnerNotificationsService _ownerNotificationsService;

  Future<List<OwnerConversationNotification>> listConversations({int perPage = 30}) {
    return _ownerNotificationsService.listConversationNotifications(perPage: perPage);
  }

  Future<List<OwnerChatMessage>> listMessages(int conversationId, {int perPage = 50}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/conversations/$conversationId/messages',
      queryParameters: <String, dynamic>{'per_page': perPage},
    );

    final data = response.data;
    if (data == null) {
      return const <OwnerChatMessage>[];
    }

    final rawItems = _extractItems(data['data']);
    return rawItems
        .map((item) => OwnerChatMessage.fromJson(item))
        .toList(growable: false);
  }

  Future<void> sendTextMessage({required int conversationId, required String body}) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/owner/messages',
      data: <String, dynamic>{
        'conversation_id': conversationId,
        'body': body,
      },
    );
  }

  Future<void> markConversationAsRead(int conversationId) {
    return _ownerNotificationsService.markConversationAsRead(conversationId);
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