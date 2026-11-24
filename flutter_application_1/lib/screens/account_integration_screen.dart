import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'root_screen.dart';

String get _kBaseUrl => ApiConfig.baseUrl;

class AccountIntegrationScreen extends StatefulWidget {
  final String email;
  final String authToken;

  const AccountIntegrationScreen({
    super.key,
    required this.email,
    required this.authToken,
  });

  @override
  State<AccountIntegrationScreen> createState() =>
      _AccountIntegrationScreenState();
}

class _AccountIntegrationScreenState extends State<AccountIntegrationScreen>
    with TickerProviderStateMixin {
  int _bankCount = 0;
  int _cardCount = 0;
  int _transactionCount = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  int _currentStep = 0;
  bool _isCompleted = false;

  final List<_IntegrationStep> _steps = const [
    _IntegrationStep(
      icon: Icons.account_balance_rounded,
      title: '은행 계좌 연동',
      description: '국민, 신한, 하나, 우리 등\n주요 은행 계좌를 불러오는 중...',
      duration: 2200,
    ),
    _IntegrationStep(
      icon: Icons.credit_card_rounded,
      title: '카드 정보 수집',
      description: '신용카드 및 체크카드\n사용 내역을 분석하는 중...',
      duration: 2000,
    ),
    _IntegrationStep(
      icon: Icons.receipt_long_rounded,
      title: '거래 내역 동기화',
      description: '최근 거래 내역을\n안전하게 동기화하는 중...',
      duration: 1800,
    ),
    _IntegrationStep(
      icon: Icons.auto_awesome_rounded,
      title: 'AI 소비 패턴 분석',
      description: '나만을 위한 맞춤형\n카드 추천 데이터 생성 중...',
      duration: 2000,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
    _startIntegration();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startIntegration() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      setState(() => _currentStep = i);
      _fadeController.reset();
      _fadeController.forward();

      await Future.delayed(Duration(milliseconds: _steps[i].duration));
      if (!mounted) return;
    }

    await _fetchIntegratedAssets();
    if (!mounted) return;

    setState(() => _isCompleted = true);
    _fadeController.reset();
    _fadeController.forward();
  }

  Future<void> _fetchIntegratedAssets() async {
    try {
      final userEmail = widget.email.trim();

      final res = await http.get(
        Uri.parse('$_kBaseUrl/integrated-assets/$userEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.authToken}',
        },
      );

      debugPrint('integrated-assets status: ${res.statusCode}');
      debugPrint('integrated-assets body: ${res.body}');

      if (res.statusCode != 200) {
        _showMessage('자산 정보를 가져오지 못했습니다. 오류 코드: ${res.statusCode}');
        return;
      }

      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;

      final List<dynamic> myRegisteredCards =
          (data['myregisteredcards'] as List?) ?? const [];
      final List<dynamic> availableBankCards =
          (data['availablebankcards'] as List?) ?? const [];
      final List<dynamic> transactions =
          (data['transactions'] as List?) ?? const [];
      final List<dynamic> accounts = (data['accounts'] as List?) ?? const [];

      final List<dynamic> cards = [...myRegisteredCards, ...availableBankCards];

      final Set<String> uniqueBanks = accounts
          .whereType<Map>()
          .map((acc) {
            final dynamic bank = acc['bankOrigin'] ?? acc['bankorigin'];
            return bank?.toString() ?? '';
          })
          .where((bank) => bank.isNotEmpty)
          .toSet();

      if (!mounted) return;

      setState(() {
        _cardCount = cards.length;
        _bankCount = uniqueBanks.length;
        _transactionCount = transactions.length;
      });

      debugPrint(
        'integration complete: banks=$_bankCount, cards=$_cardCount, transactions=$_transactionCount',
      );
    } catch (e) {
      debugPrint('integrated-assets error: $e');
      _showMessage('서버 연결에 실패했습니다.');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0050), Color(0xFF2D0080), Color(0xFF4A00E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isCompleted ? _buildCompleteView() : _buildProgressView(),
        ),
      ),
    );
  }

  Widget _buildProgressView() {
    final progress = (_currentStep + 1) / _steps.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.link_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '계좌 통합 중',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '잠시만 기다려주세요',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toInt()}% 완료',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${_currentStep + 1} / ${_steps.length}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const _LoadingDots(),
                  const SizedBox(height: 20),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      _steps[_currentStep].icon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _steps[_currentStep].title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _steps[_currentStep].description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) {
              final isDone = i < _currentStep;
              final isCurrent = i == _currentStep;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isCurrent ? 28 : 10,
                height: 10,
                decoration: BoxDecoration(
                  color: (isDone || isCurrent)
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(5),
                ),
              );
            }),
          ),
          const SizedBox(height: 40),
          Text(
            '금융 정보는 암호화되어 안전하게 처리됩니다.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteView() {
    final bankLabel = _bankCount > 0 ? '$_bankCount개' : '없음';
    final cardLabel = _cardCount > 0 ? '$_cardCount개' : '없음';
    final txLabel = _transactionCount > 0
        ? (_transactionCount > 100
              ? '100+건'
              : '${_transactionCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}건')
        : '없음';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '통합 완료!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '모든 계좌 정보가 성공적으로\n통합되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 17,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    Icons.account_balance_rounded,
                    '연동된 은행',
                    bankLabel,
                  ),
                  const Divider(color: Colors.white24, height: 28),
                  _buildSummaryRow(
                    Icons.credit_card_rounded,
                    '등록된 카드',
                    cardLabel,
                  ),
                  const Divider(color: Colors.white24, height: 28),
                  _buildSummaryRow(
                    Icons.receipt_long_rounded,
                    '최근 거래 수',
                    txLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const RootScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4A00E0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '서비스 시작하기',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    final isEmpty = value == '없음';

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 15,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: isEmpty ? Colors.white54 : Colors.white,
            fontSize: 16,
            fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _IntegrationStep {
  final IconData icon;
  final String title;
  final String description;
  final int duration;

  const _IntegrationStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.duration,
  });
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
            final dy = -6.0 * scale + 3.0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.4 + 0.6 * scale),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
