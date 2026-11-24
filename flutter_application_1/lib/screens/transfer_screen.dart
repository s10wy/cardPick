import 'package:flutter/material.dart';

class TransferScreen extends StatefulWidget {
  final num currentBalance;
  const TransferScreen({super.key, this.currentBalance = 1250000});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountController = TextEditingController();
  final _receiverController = TextEditingController();
  String _selectedBank = '신한은행';
  num _transferAmount = 0;

  final List<Map<String, dynamic>> _banks = [
    {'name': '신한은행', 'color': Colors.blue.shade600, 'icon': Icons.account_balance_rounded},
    {'name': 'KB국민은행', 'color': Colors.amber.shade600, 'icon': Icons.account_balance_wallet_rounded},
    {'name': '우리은행', 'color': Colors.lightBlue.shade600, 'icon': Icons.savings_rounded},
    {'name': '하나은행', 'color': Colors.teal.shade600, 'icon': Icons.monetization_on_rounded},
    {'name': '카카오뱅크', 'color': Colors.yellow.shade700, 'icon': Icons.chat_bubble_rounded},
    {'name': '토스뱅크', 'color': Colors.blueAccent, 'icon': Icons.bolt_rounded},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _receiverController.dispose();
    super.dispose();
  }

  void _addAmount(num amount) {
    setState(() {
      _transferAmount += amount;
      if (_transferAmount > widget.currentBalance) {
        _transferAmount = widget.currentBalance;
      }
      _amountController.text = _formatNumber(_transferAmount);
    });
  }

  String _formatNumber(num val) {
    return val.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  void _executeTransfer() {
    if (_transferAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이체할 금액을 입력해주세요.')),
      );
      return;
    }
    if (_receiverController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('받는 사람의 이름을 입력해주세요.')),
      );
      return;
    }

    // 성공 다이얼로그 연출
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildSuccessDialog(),
    );
  }

  Widget _buildSuccessDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, val, child) => Transform.scale(scale: val, child: child),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 50),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '이체 완료!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF212529),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_selectedBank ${_receiverController.text.trim()}님에게\n${_formatNumber(_transferAmount)}원을 안전하게 보냈습니다.',
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
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // 팝업 닫기
                  Navigator.pop(context); // 이체 화면 닫기
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '송금하기',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 출금 계좌 정보 잔액
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A00E0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF4A00E0), size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Text('내 통장 잔액', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${_formatNumber(widget.currentBalance)}원', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4A00E0))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 은행 선택
                    Text('받는 은행', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _banks.length,
                        itemBuilder: (context, index) {
                          final bank = _banks[index];
                          final isSelected = _selectedBank == bank['name'];
                          return GestureDetector(
                            onTap: () => setState(() => _selectedBank = bank['name']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 80,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? (bank['color'] as Color).withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? bank['color'] : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(bank['icon'], color: bank['color'], size: 28),
                                  const SizedBox(height: 8),
                                  Text(
                                    bank['name'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.black87 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 받는 사람 이름
                    Text('받는 사람', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _receiverController,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '이름 입력 (예: 홍길동)',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 금액 입력
                    Text('보낼 금액', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      readOnly: true,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF212529)),
                      decoration: InputDecoration(
                        hintText: '0원',
                        hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 32, fontWeight: FontWeight.w800),
                        border: InputBorder.none,
                        suffixText: '원',
                        suffixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF212529)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 금액 간편 버튼
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickAmountBtn('+1만', 10000),
                        _buildQuickAmountBtn('+5만', 50000),
                        _buildQuickAmountBtn('+10만', 100000),
                        _buildQuickAmountBtn('+100만', 1000000),
                        ActionChip(
                          label: const Text('전액', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onPressed: () {
                            setState(() {
                              _transferAmount = widget.currentBalance;
                              _amountController.text = _formatNumber(_transferAmount);
                            });
                          },
                        ),
                        if (_transferAmount > 0)
                          ActionChip(
                            label: const Text('정정', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                            backgroundColor: Colors.red.shade50,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onPressed: () {
                              setState(() {
                                _transferAmount = 0;
                                _amountController.text = '';
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 이체 버튼
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _executeTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A00E0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    '이체하기',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountBtn(String label, num amt) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A00E0))),
      backgroundColor: const Color(0xFF4A00E0).withOpacity(0.06),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () => _addAmount(amt),
    );
  }
}
