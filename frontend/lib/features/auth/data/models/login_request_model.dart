class LoginRequestModel {
  const LoginRequestModel({
    required this.email,
    required this.password,
    this.deviceId,
  });

  final String email;
  final String password;
  final String? deviceId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
    };
  }
}
