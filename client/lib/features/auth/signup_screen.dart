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

/// 회원가입. 가입하면 바로 로그인되고, 라우터가 홈으로 보낸다.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();

  bool _submitted = false;
  bool _busy = false;
  String? _serverError;

  @override
  void dispose() {
    for (final c in [_email, _password, _nickname]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _show(String? error) => _submitted ? error : null;

  String? get _emailError => _show(AuthValidators.email(_email.text));
  String? get _passwordError =>
      _show(AuthValidators.newPassword(_password.text));
  String? get _nicknameError => _show(AuthValidators.nickname(_nickname.text));

  Future<void> _submit() async {
    setState(() {
      _submitted = true;
      _serverError = null;
    });
    if (_emailError != null ||
        _passwordError != null ||
        _nicknameError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signup(
            email: _email.text,
            password: _password.text,
            nickname: _nickname.text,
          );
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void changed(String _) => setState(() {});

    return AuthLayout(
      title: '회원가입',
      error: _serverError,
      fields: [
        AppTextField(
          label: '이메일',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          errorText: _emailError,
          onChanged: changed,
        ),
        AppTextField(
          label: '비밀번호 (8자 이상)',
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.next,
          errorText: _passwordError,
          onChanged: changed,
        ),
        AppTextField(
          label: '닉네임',
          controller: _nickname,
          textInputAction: TextInputAction.done,
          errorText: _nicknameError,
          onChanged: changed,
          onSubmitted: (_) => _submit(),
        ),
      ],
      submit: PillButton(
        label: '가입하기',
        onPressed: _submit,
        isLoading: _busy,
        expand: true,
      ),
      footer: TextLinkButton(
        label: '이미 계정이 있어요. 로그인',
        onPressed: () => context.go(AppRoutes.login),
      ),
    );
  }
}
