class AdminLoginResponseModel {
  const AdminLoginResponseModel({required this.token});

  final String token;

  factory AdminLoginResponseModel.fromJson(Map<String, dynamic> json) {
    final payload = _extractPayload(json);
    final tokenRaw = payload['token'];

    if (tokenRaw is! String || tokenRaw.isEmpty) {
      throw Exception('Admin login response does not include a valid token');
    }

    return AdminLoginResponseModel(token: tokenRaw);
  }

  static Map<String, dynamic> _extractPayload(Map<String, dynamic> json) {
    final data = json['data'];

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return json;
  }
}
