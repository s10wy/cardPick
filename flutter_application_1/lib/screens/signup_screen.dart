// lib/screens/signup_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'account_integration_screen.dart';

const _kPrimary = Color(0xFF4A00E0);
const _kPrimaryEnd = Color(0xFF8E2DE2);
const _kDark = Color(0xFF212529);

String get _kBaseUrl => '${ApiConfig.baseUrl}/api/auth';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isCodeSent = false;
  bool _isEmailVerified = false;
  bool _isEmailSending = false;
  bool _isSigningUp = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('이메일을 입력해주세요.');
      return;
    }

    setState(() => _isEmailSending = true);

    try {
      final res = await http
          .post(
            Uri.parse('$_kBaseUrl/send-code'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() => _isCodeSent = true);
        debugPrint('send-code response: ${res.body}');
        _showMessage('인증번호가 발송되었습니다.');
      } else {
        _showMessage('인증번호 전송에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('send-code error: $e');
      if (!mounted) return;
      _showMessage('서버에 연결할 수 없습니다.');
    } finally {
      if (mounted) {
        setState(() => _isEmailSending = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty) {
      _showMessage('이메일을 입력해주세요.');
      return;
    }

    if (code.isEmpty) {
      _showMessage('인증번호를 입력해주세요.');
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (!mounted) return;

      if (res.statusCode == 200 && res.body.trim() == 'true') {
        setState(() => _isEmailVerified = true);
        _showMessage('이메일 인증이 완료되었습니다!');
      } else {
        _showMessage('인증번호가 일치하지 않습니다.');
      }
    } catch (e) {
      debugPrint('verify-code error: $e');
      if (!mounted) return;
      _showMessage('서버에 연결할 수 없습니다.');
    }
  }

  Future<void> _signup({required bool withIntegration}) async {
    if (_isSigningUp) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    setState(() => _isSigningUp = true);

    try {
      final res = await http.post(
        Uri.parse('$_kBaseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'name': name}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(res.body) as Map<String, dynamic>;
        final String loginToken = (data['token'] ?? '').toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userEmail', email);
        await prefs.setString('authToken', loginToken);

        debugPrint('signup token saved');

        if (!mounted) return;

        if (withIntegration) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AccountIntegrationScreen(email: email, authToken: loginToken),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } else if (res.statusCode == 409) {
        _showMessage('이미 가입된 이메일입니다. 로그인을 이용해주세요.');
      } else {
        _showMessage('회원가입에 실패했습니다. (${res.statusCode}) 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('signup error: $e');
      if (!mounted) return;
      _showMessage('서버와 연결할 수 없습니다. 인터넷 연결을 확인하세요.');
    } finally {
      if (mounted) {
        setState(() => _isSigningUp = false);
      }
    }
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('이름을 입력해주세요.');
      return false;
    }

    if (_emailController.text.trim().isEmpty) {
      _showMessage('이메일을 입력해주세요.');
      return false;
    }

    if (!_isEmailVerified) {
      _showMessage('이메일 인증을 완료해주세요.');
      return false;
    }

    if (_passwordController.text.length < 8) {
      _showMessage('비밀번호는 8자리 이상이어야 합니다.');
      return false;
    }

    if (_passwordController.text != _passwordConfirmController.text) {
      _showMessage('비밀번호가 일치하지 않습니다.');
      return false;
    }

    return true;
  }

  void _showMessage(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showIntegrationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kPrimaryEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '계좌 통합으로\n더 스마트한 추천을!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: -0.5,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '흩어진 계좌를 하나로 연결하면\nAI가 나에게 딱 맞는 카드를 추천해드려요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            const _BenefitRow(
              icon: Icons.auto_awesome_rounded,
              title: '맞춤형 카드 추천',
              subtitle: '소비 패턴 기반 AI 분석',
            ),
            const SizedBox(height: 14),
            const _BenefitRow(
              icon: Icons.bar_chart_rounded,
              title: '자동 가계부',
              subtitle: '거래내역 자동 분류 및 통계',
            ),
            const SizedBox(height: 14),
            const _BenefitRow(
              icon: Icons.lock_outline_rounded,
              title: '안전한 연결',
              subtitle: '금융보안원 인증 보안 적용',
            ),
            const SizedBox(height: 32),
            _GradientButton(
              label: _isSigningUp ? '처리 중...' : '계좌 통합 시작하기',
              onTap: () {
                if (_isSigningUp) return;
                Navigator.of(ctx).pop();
                _signup(withIntegration: true);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: _isSigningUp
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _signup(withIntegration: false);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '나중에 할게요',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBtn({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Widget? sideButton,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kDark,
          ),
        ),
        const SizedBox(height: 8),
        if (sideButton != null)
          Row(
            children: [
              Expanded(
                child: _TextInput(
                  controller: controller,
                  hint: hint,
                  icon: icon,
                  isPassword: isPassword,
                ),
              ),
              const SizedBox(width: 12),
              sideButton,
            ],
          )
        else
          _TextInput(
            controller: controller,
            hint: hint,
            icon: icon,
            isPassword: isPassword,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                '새로운 여정을\n시작해볼까요?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  letterSpacing: -1.0,
                  color: _kDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '간단한 정보 입력으로 가입을 완료하세요.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              _buildField(
                label: '이름',
                controller: _nameController,
                hint: '홍길동',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 24),
              _buildField(
                label: '이메일',
                controller: _emailController,
                hint: 'example@email.com',
                icon: Icons.email_outlined,
                sideButton: _buildSideBtn(
                  label: _isEmailSending
                      ? '전송 중...'
                      : (_isCodeSent ? '재전송' : '인증요청'),
                  color: _kPrimary,
                  enabled: !_isEmailVerified && !_isEmailSending,
                  onTap: _sendCode,
                ),
              ),
              if (_isCodeSent) ...[
                const SizedBox(height: 16),
                _buildField(
                  label: '인증번호',
                  controller: _codeController,
                  hint: '인증번호 6자리',
                  icon: Icons.check_circle_outline,
                  sideButton: _buildSideBtn(
                    label: _isEmailVerified ? '완료' : '확인',
                    color: _kDark,
                    enabled: !_isEmailVerified,
                    onTap: _verifyCode,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildField(
                label: '비밀번호',
                controller: _passwordController,
                hint: '8자리 이상 입력해주세요',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),
              const SizedBox(height: 16),
              _buildField(
                label: '비밀번호 확인',
                controller: _passwordConfirmController,
                hint: '비밀번호를 한번 더 입력해주세요',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),
              const SizedBox(height: 40),
              _GradientButton(
                label: _isSigningUp ? '처리 중...' : '회원가입 완료',
                onTap: () {
                  if (_isSigningUp) return;
                  if (_validate()) {
                    _showIntegrationSheet();
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextInput extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;

  const _TextInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
  });

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscure,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _kDark,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
          prefixIcon: Icon(widget.icon, color: Colors.grey.shade500, size: 22),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kPrimary, _kPrimaryEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kPrimary, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }
}
