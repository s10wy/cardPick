import 'package:flutter/material.dart';
import 'dart:async';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SingleTickerProviderStateMixin {
  int _selectedCardIndex = 0;
  int _barcodeTimer = 180; // 3분 타이머
  Timer? _timer;
  late AnimationController _glowController;

  final List<Map<String, dynamic>> _virtualCards = [
    {
      'name': '신한 Deep Dream Platinum+',
      'type': 'VISA',
      'last4': '4251',
      'color1': const Color(0xFF1a0050),
      'color2': const Color(0xFF4A00E0),
    },
    {
      'name': 'KB국민 탄탄대로 올쇼핑',
      'type': 'MasterCard',
      'last4': '8832',
      'color1': const Color(0xFF2C3E50),
      'color2': const Color(0xFFBDC3C7),
    },
    {
      'name': '네이버페이 우리카드',
      'type': '국내전용',
      'last4': '1120',
      'color1': const Color(0xFF00C73C),
      'color2': const Color(0xFF00912B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_barcodeTimer > 0) {
          _barcodeTimer--;
        } else {
          _barcodeTimer = 180; // 리셋
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _simulatePaymentSuccess() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSuccessSheet(),
    );
  }

  Widget _buildSuccessSheet() {
    final card = _virtualCards[_selectedCardIndex];
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.nfc_rounded, color: Colors.blue.shade600, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            '결제가 승인되었습니다',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF212529),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${card['name']} (${card['last4']})\n오프라인 가맹점 간편 결제 완료',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // 시트 닫기
                Navigator.pop(context); // 결제 화면 닫기
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('확인', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCard = _virtualCards[_selectedCardIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // 결제용 다크 모드
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '오프라인 결제',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 카드 리스트 선택 (가로 스와이프)
            SizedBox(
              height: 190,
              child: PageView.builder(
                physics: const BouncingScrollPhysics(),
                controller: PageController(viewportFraction: 0.85),
                onPageChanged: (index) => setState(() => _selectedCardIndex = index),
                itemCount: _virtualCards.length,
                itemBuilder: (context, index) {
                  final card = _virtualCards[index];
                  final isSelected = index == _selectedCardIndex;
                  return AnimatedScale(
                    scale: isSelected ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [card['color1'], card['color2']],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: card['color2'].withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                card['type'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 24),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            card['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '**** **** **** ${card['last4']}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 15,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 페이지 인디케이터
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _virtualCards.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _selectedCardIndex ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _selectedCardIndex ? Colors.white : Colors.white38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 바코드 및 QR 영역
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 상단 타이머 및 갱신
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '바코드 유효시간  ',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _formatTime(_barcodeTimer),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF4A00E0), fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _barcodeTimer = 180),
                          child: const Icon(Icons.refresh_rounded, color: Colors.black38, size: 18),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 시뮬레이션 바코드 그래픽
                    SizedBox(
                      height: 75,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildBar(4), _buildBar(2), _buildBar(6), _buildBar(1),
                          _buildBar(3), _buildBar(8), _buildBar(2), _buildBar(5),
                          _buildBar(1), _buildBar(4), _buildBar(2), _buildBar(6),
                          _buildBar(2), _buildBar(1), _buildBar(7), _buildBar(3),
                          _buildBar(5), _buildBar(2), _buildBar(1), _buildBar(4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      '8809  1245  ${selectedCard['last4']}  0023',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.0,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 시뮬레이션 QR 그래픽
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, size: 90, color: Colors.black87),
                    ),

                    const SizedBox(height: 16),

                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) => Opacity(
                        opacity: 0.5 + (_glowController.value * 0.5),
                        child: Text(
                          '가맹점 리더기에 스캔해주세요',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 가상 결제 완료 트리거 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _simulatePaymentSuccess,
                  icon: const Icon(Icons.nfc_rounded, color: Colors.black87, size: 20),
                  label: const Text(
                    '결제 스캔 완료 시뮬레이션',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(double width) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      color: Colors.black87,
    );
  }
}
