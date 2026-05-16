enum LoginType {
  endUser,
  owner,
  admin,
}

class LoginCredentialsEntity {
  const LoginCredentialsEntity({
    required this.email,
    required this.password,
    required this.loginType,
    this.deviceId,
  });

  final String email;
  final String password;
  final LoginType loginType;
  final String? deviceId;
}
