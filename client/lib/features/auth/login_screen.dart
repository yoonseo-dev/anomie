import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../shared/data/api_client.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/pill_button.dart';
import '../../shared/widgets/text_link_button.dart';
import 'auth_controller.dart';
import 'auth_validators.dart';
import 'widgets/auth_layout.dart';

/// 로그인. 성공하면 라우터가 홈으로 보낸다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// 버튼을 한 번 누른 뒤부터 입력 오류를 보여 준다.
  bool _submitted = false;
  bool _busy = false;
  String? _serverError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _emailError =>
      _submitted ? AuthValidators.email(_email.text) : null;
  String? get _passwordError =>
      _submitted ? AuthValidators.password(_password.text) : null;

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: _email.text, password: _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: '로그인',
      error: _serverError,
      fields: [
        AppTextField(
          label: '이메일',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          errorText: _emailError,
          onChanged: (_) => setState(() {}),
        ),
        AppTextField(
          label: '비밀번호',
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          errorText: _passwordError,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ],
      submit: PillButton(
        label: '로그인',
        onPressed: _submit,
        isLoading: _busy,
        expand: true,
      ),
      footer: TextLinkButton(
        label: '처음이에요? 회원가입',
        onPressed: () => context.go(AppRoutes.signup),
      ),
    );
  }
}
