import 'dart:convert';

/// 로그인·회원가입 입력 검사. 서버(`server/src/routes/auth.js`)와 같은 기준이다. 통과하면 null.
abstract final class AuthValidators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String value) {
    final v = value.trim();
    if (v.isEmpty) return '이메일을 입력해 주세요';
    if (!_email.hasMatch(v) || v.length > 254) return '이메일 형식이 올바르지 않아요';
    return null;
  }

  /// 가입할 때만 길이를 본다. 로그인은 비어 있지만 않으면 된다.
  static String? newPassword(String value) {
    if (value.length < 8) return '비밀번호는 8자 이상이어야 해요';
    // 서버(bcrypt)는 72바이트까지만 쓴다. 한글은 한 글자가 3바이트.
    if (utf8.encode(value).length > 72) return '비밀번호가 너무 길어요';
    return null;
  }

  static String? password(String value) =>
      value.isEmpty ? '비밀번호를 입력해 주세요' : null;

  static String? nickname(String value) {
    final v = value.trim();
    if (v.isEmpty) return '닉네임을 입력해 주세요';
    if (v.length > 30) return '닉네임은 30자까지 쓸 수 있어요';
    return null;
  }
}
