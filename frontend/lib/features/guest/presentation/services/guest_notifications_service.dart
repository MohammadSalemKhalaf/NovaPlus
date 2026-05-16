import '../../../../core/api/api_client.dart';

class GuestNotificationItem {
  const GuestNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.channel,
    required this.priority,
    required this.status,
    required this.isRead,
    required this.createdAt,
    this.relatedType,
    this.relatedId,
    this.readAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final String channel;
  final String priority;
  final String status;
  final bool isRead;
  final String? relatedType;
  final int? relatedId;
  final DateTime? readAt;
  final DateTime? createdAt;

  int? get conversationId {
    if (relatedType == 'conversation' && relatedId != null && relatedId! > 0) {
      return relatedId;
    }
    return null;
  }

  String? get senderName {
    // Expected body example from backend:
    // "John replied to your chat with NovaPlus Demo."
    final normalizedBody = body.trim();
    if (normalizedBody.isEmpty) {
      return null;
    }

    const marker = ' replied to your chat with ';
    final index = normalizedBody.indexOf(marker);
    if (index <= 0) {
      return null;
    }

    final sender = normalizedBody.substring(0, index).trim();
    return sender.isEmpty ? null : sender;
  }

  String? get tenantName {
    const marker = ' replied to your chat with ';
    final normalizedBody = body.trim();
    final index = normalizedBody.indexOf(marker);
    if (index < 0) {
      return null;
    }

    final tail = normalizedBody.substring(index + marker.length).trim();
    final cleaned = tail.endsWith('.') ? tail.substring(0, tail.length - 1).trim() : tail;
    return cleaned.isEmpty ? null : cleaned;
  }

  factory GuestNotificationItem.fromJson(Map<String, dynamic> json) {
    return GuestNotificationItem(
      id: _readInt(json['id']),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      relatedType: json['related_type']?.toString(),
      relatedId: _readNullableInt(json['related_id']),
      channel: json['channel']?.toString() ?? 'database',
      priority: json['priority']?.toString() ?? 'normal',
      status: json['status']?.toString() ?? 'sent',
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

class GuestNotificationsService {
  GuestNotificationsService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<GuestNotificationItem>> listNotifications({int perPage = 20}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/enduser/notifications',
      queryParameters: <String, dynamic>{'per_page': perPage},
    );

    final data = response.data;
    if (data == null) {
      return const <GuestNotificationItem>[];
    }

    final rawItems = _extractItems(data['data']);
    return rawItems
        .whereType<Map>()
        .map((item) => GuestNotificationItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<int> unreadCount() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/enduser/notifications/unread-count');
    final data = response.data;
    if (data == null) {
      return 0;
    }

    final payload = data['data'];
    if (payload is Map) {
      return int.tryParse(payload['count']?.toString() ?? '') ?? 0;
    }

    return 0;
  }

  Future<void> markAsRead(int notificationId) async {
    await _apiClient.post<Map<String, dynamic>>('/enduser/notifications/$notificationId/read');
  }

  Future<int> markAllAsRead() async {
    final response = await _apiClient.post<Map<String, dynamic>>('/enduser/notifications/read-all');
    final data = response.data;
    if (data == null) {
      return 0;
    }

    final payload = data['data'];
    if (payload is Map) {
      return int.tryParse(payload['updated_count']?.toString() ?? '') ?? 0;
    }

    return 0;
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