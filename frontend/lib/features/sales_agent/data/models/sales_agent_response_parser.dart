class SalesAgentResponseParser {
  const SalesAgentResponseParser._();

  static Map<String, dynamic> dataMap(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> dataList(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  static List<Map<String, dynamic>> dataListByKey(
    Map<String, dynamic> payload,
    String key,
  ) {
    final data = payload['data'];
    if (data is! Map) {
      return const <Map<String, dynamic>>[];
    }

    final map = Map<String, dynamic>.from(data);
    final rawList = map[key];
    if (rawList is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static void ensureSuccess(
    Map<String, dynamic> payload, {
    required String fallbackMessage,
  }) {
    final success = payload['success'];
    if (success is bool && !success) {
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        throw Exception(message.trim());
      }
      throw Exception(fallbackMessage);
    }
  }
}
