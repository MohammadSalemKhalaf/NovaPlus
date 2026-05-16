import '../../../../core/api/api_client.dart';

class OwnerConversationNotification {
  const OwnerConversationNotification({
    required this.conversationId,
    required this.endUserName,
    required this.lastMessagePreview,
    required this.unreadCount,
    this.lastMessageAt,
  });

  final int conversationId;
  final String endUserName;
  final String? lastMessagePreview;
  final int unreadCount;
  final DateTime? lastMessageAt;

  factory OwnerConversationNotification.fromJson(Map<String, dynamic> json) {
    final endUser = json['end_user'];
    final endUserName = endUser is Map
        ? (endUser['name']?.toString().trim() ?? '')
        : '';

    return OwnerConversationNotification(
      conversationId: _readInt(json['id']),
      endUserName: endUserName.isEmpty ? 'Guest user' : endUserName,
      lastMessagePreview: json['last_message_preview']?.toString(),
      unreadCount: _readInt(json['unread_count']),
      lastMessageAt: _readDateTime(json['last_message_at']),
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

class OwnerNotificationsService {
  OwnerNotificationsService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<OwnerConversationNotification>> listConversationNotifications({int perPage = 25}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/owner/conversations',
      queryParameters: <String, dynamic>{'per_page': perPage},
    );

    final data = response.data;
    if (data == null) {
      return const <OwnerConversationNotification>[];
    }

    final rawItems = _extractItems(data['data']);
    return rawItems
        .map((item) => OwnerConversationNotification.fromJson(item))
        .toList(growable: false);
  }

  Future<int> unreadCount() async {
    final conversations = await listConversationNotifications(perPage: 50);
    return conversations.fold<int>(0, (count, item) => count + item.unreadCount);
  }

  Future<void> markConversationAsRead(int conversationId) async {
    await _apiClient.post<Map<String, dynamic>>('/conversations/$conversationId/read');
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