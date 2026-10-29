/// 로그인한 사용자 (서버 User의 공개 정보).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.nickname,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    nickname: json['nickname'] as String,
  );

  final String id;
  final String email;
  final String nickname;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'nickname': nickname,
  };
}

/// 로그인 상태. Access 토큰(15분)으로 API를 부르고, 만료되면 Refresh 토큰(30일)으로 둘 다 새로 받는다.
class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  Session withTokens({
    required String accessToken,
    required String refreshToken,
  }) =>
      Session(accessToken: accessToken, refreshToken: refreshToken, user: user);

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': user.toJson(),
  };
}
