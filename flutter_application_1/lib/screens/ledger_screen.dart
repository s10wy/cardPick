import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Transaction {
  final String title;
  final String category;
  final DateTime date;
  final int amount;
  final bool isExpense;
  final IconData icon;
  final Color iconColor;

  Transaction({
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
    this.isExpense = true,
    required this.icon,
    required this.iconColor,
  });
}

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  int totalExpense = 0;
  int totalIncome = 0;
  int monthlyBudget = 1000000;
  
  late Future<List<Transaction>> _transactionsFuture;
  
  @override
  void initState() {
    super.initState();
    _transactionsFuture = _loadTransactions();
  }

  Future<List<Transaction>> _loadTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) {
      return [];
    }

    final assets = await ApiService.fetchIntegratedAssets(email);
    int budget = 1000000;
    if (assets != null && assets['monthly_budget'] != null) {
      budget = int.tryParse(assets['monthly_budget'].toString()) ?? 1000000;
    }

    final transactions = await ApiService.fetchCurrentMonthTransactions(email);
    if (mounted) {
      int expense = 0;
      int income = 0;
      for (var tx in transactions) {
        if (tx.isExpense) {
          expense += tx.amount;
        } else {
          income += tx.amount;
        }
      }
      setState(() {
        totalExpense = expense;
        totalIncome = income;
        monthlyBudget = budget;
      });
    }
    return transactions;
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = DateTime(now.year, now.month, now.day).difference(DateTime(date.year, date.month, date.day)).inDays;
    
    if (difference == 0) return '오늘';
    if (difference == 1) return '어제';
    return '${date.month}월 ${date.day}일';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '가계부',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.black87),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 32),
              const Text(
                '최근 결제 내역',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF212529),
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Transaction>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('에러 발생: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(
                        child: Text('이번 달 거래 내역이 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ),
                    );
                  }
                  return _buildTransactionList(snapshot.data!);
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(28.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '이번 달 총 지출',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C757D),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A00E0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '예산의 ${monthlyBudget > 0 ? (totalExpense / monthlyBudget * 100).toInt() : 0}% 사용',
                  style: const TextStyle(
                    color: Color(0xFF4A00E0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatCurrency(totalExpense),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF212529),
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '원',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212529),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  title: '수입',
                  amount: totalIncome,
                  color: const Color(0xFF42A5F5),
                  isExpense: false,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildSummaryItem(
                    title: '지출',
                    amount: totalExpense,
                    color: const Color(0xFFEF5350),
                    isExpense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({required String title, required int amount, required Color color, required bool isExpense}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatCurrency(amount)}원',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212529),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    // Group transactions by date
    Map<String, List<Transaction>> grouped = {};
    for (var tx in transactions) {
      String dateStr = _formatDate(tx.date);
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(tx);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0, top: 16.0),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: entry.value.asMap().entries.map((txEntry) {
                  int idx = txEntry.key;
                  Transaction tx = txEntry.value;
                  bool isLast = idx == entry.value.length - 1;

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: tx.iconColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(tx.icon, color: tx.iconColor, size: 24),
                        ),
                        title: Text(
                          tx.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF212529),
                          ),
                        ),
                        subtitle: Text(
                          tx.category,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          '${tx.isExpense ? "-" : "+"}${_formatCurrency(tx.amount)}원',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: tx.isExpense ? const Color(0xFF212529) : const Color(0xFF42A5F5),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Divider(height: 1, color: Colors.grey.shade100, indent: 76, endIndent: 20),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
