import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'ledger_screen.dart';

class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';

    final assets =
        email.isNotEmpty ? await ApiService.fetchIntegratedAssets(email) : null;
    final List<Transaction> transactions =
        email.isNotEmpty ? await ApiService.fetchCurrentMonthTransactions(email) : [];
    final recommendedCards =
        email.isNotEmpty ? await ApiService.fetchRecommendedCards(email) : [];

    final userName =
        assets?['username'] as String? ??
        assets?['user_name'] as String? ??
        '고객';

    final Map<String, int> categorySums = {};
    int totalExpense = 0;

    for (var tx in transactions) {
      if (tx.isExpense) {
        categorySums[tx.category] = (categorySums[tx.category] ?? 0) + tx.amount;
        totalExpense += tx.amount;
      }
    }

    final sortedEntries = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    final spendingData = <Map<String, dynamic>>[];
    for (int i = 0; i < sortedEntries.length; i++) {
      final cat = sortedEntries[i].key;
      final amt = sortedEntries[i].value;
      final pct = totalExpense > 0 ? amt / totalExpense : 0.0;

      spendingData.add({
        'category': cat,
        'percent': pct,
        'amount': _formatWon(amt),
        'color': colors[i % colors.length],
      });
    }

    final patternSubtitle = sortedEntries.length >= 3
        ? '${sortedEntries[0].key}, ${sortedEntries[1].key}, ${sortedEntries[2].key} 중심 소비 패턴이에요.'
        : sortedEntries.length == 2
            ? '${sortedEntries[0].key}와 ${sortedEntries[1].key}에 지출이 집중되어 있어요.'
            : sortedEntries.length == 1
                ? '${sortedEntries[0].key}에 지출이 가장 많아요.'
                : '이번 달 지출 내역이 없어 분석할 수 없습니다.';

    return {
      'userName': userName,
      'spendingData': spendingData,
      'patternSubtitle': patternSubtitle,
      'cards': recommendedCards,
    };
  }

  String _formatWon(num amount) {
    final value = amount.toInt().toString();
    final formatted = value.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${formatted}원';
  }

  String _bankLabel(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'hana':
        return '하나은행';
      case 'kukmin':
        return '국민은행';
      case 'noori':
        return '누리은행';
      default:
        return bankName;
    }
  }

  List<Color> _getCardPalette(String bankName, String title, List<dynamic> matchedCategories) {
    final text = '$bankName $title ${matchedCategories.join(" ")}'.toLowerCase();

    if (bankName.toLowerCase() == 'hana') {
      return const [Color(0xFF00897B), Color(0xFF26A69A)];
    }
    if (bankName.toLowerCase() == 'kukmin') {
      return const [Color(0xFFFFC107), Color(0xFFFFD54F)];
    }
    if (bankName.toLowerCase() == 'noori') {
      return const [Color(0xFF5E35B1), Color(0xFF7E57C2)];
    }

    if (text.contains('shopping') || text.contains('쇼핑')) {
      return const [Color(0xFF2E7D32), Color(0xFF66BB6A)];
    }
    if (text.contains('food') || text.contains('식비')) {
      return const [Color(0xFFFF7043), Color(0xFFFF8A65)];
    }
    if (text.contains('cafe') || text.contains('카페')) {
      return const [Color(0xFF6D4C41), Color(0xFF8D6E63)];
    }
    if (text.contains('oil') || text.contains('주유')) {
      return const [Color(0xFF3949AB), Color(0xFF5C6BC0)];
    }

    return const [Color(0xFF1E3C72), Color(0xFF2A5298)];
  }

  IconData _getCardIcon(String title, String bankName, List<dynamic> matchedCategories) {
    final text = '$title $bankName ${matchedCategories.join(" ")}'.toLowerCase();

    if (text.contains('cafe') || text.contains('카페') || text.contains('커피')) {
      return Icons.local_cafe_rounded;
    }
    if (text.contains('food') || text.contains('식비') || text.contains('치킨')) {
      return Icons.restaurant_rounded;
    }
    if (text.contains('shopping') || text.contains('쇼핑') || text.contains('마트')) {
      return Icons.shopping_bag_rounded;
    }
    if (text.contains('travel') || text.contains('여행') || text.contains('항공')) {
      return Icons.flight_rounded;
    }
    if (text.contains('transport') || text.contains('교통') || text.contains('주차')) {
      return Icons.directions_car_rounded;
    }
    if (text.contains('oil') || text.contains('주유')) {
      return Icons.local_gas_station_rounded;
    }
    if (text.contains('beauty') || text.contains('뷰티')) {
      return Icons.face_retouching_natural_rounded;
    }
    if (text.contains('hobby') || text.contains('취미') || text.contains('영화')) {
      return Icons.movie_rounded;
    }
    return Icons.credit_card_rounded;
  }

  String _buildMatchedCategoryText(List<dynamic> matchedCategories) {
    if (matchedCategories.isEmpty) {
      return '이번 달 소비 패턴과 맞는 혜택이 있는 카드예요.';
    }
    return '${matchedCategories.join(', ')} 소비에 강점이 있어요.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '맞춤 카드 추천',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A00E0)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                '데이터를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
              ),
            );
          }

          final data = snapshot.data ?? {};
          final userName = data['userName'] as String? ?? '고객';
          final spendingData =
              data['spendingData'] as List<Map<String, dynamic>>? ?? [];
          final patternSubtitle = data['patternSubtitle'] as String? ?? '';
          final cards = data['cards'] as List<dynamic>? ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dataFuture = _loadData();
              });
              await _dataFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이번 달 소비 패턴',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF212529),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      patternSubtitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSpendingAnalysis(spendingData),
                    const SizedBox(height: 40),
                    Text(
                      '$userName님을 위한 찰떡 카드',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF212529),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '통합 소비 패턴 + 카드 혜택 + 프로모션까지 반영한 추천 결과예요.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (cards.isEmpty)
                      _buildEmptyState()
                    else
                      ...cards.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final raw = entry.value;
                        final card = raw is Map<String, dynamic>
                            ? raw
                            : Map<String, dynamic>.from(raw as Map);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 18.0),
                          child: _buildRecommendedCard(
                            rank: idx + 1,
                            card: card,
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              color: Colors.grey.shade300,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              '추천 결과가 아직 없습니다.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingAnalysis(List<Map<String, dynamic>> spendingData) {
    if (spendingData.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            '지출 내역이 없어 소비 패턴을 표시할 수 없습니다.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: spendingData.map((data) {
          final isLast = data == spendingData.last;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data['category'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF212529),
                    ),
                  ),
                  Text(
                    data['amount'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF212529),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: data['percent'] as double,
                backgroundColor: Colors.grey.shade100,
                color: data['color'] as Color,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              if (!isLast) const SizedBox(height: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecommendedCard({
    required int rank,
    required Map<String, dynamic> card,
  }) {
    final title = (card['cardName'] ?? '추천 카드').toString();
    final bankName = (card['bankName'] ?? '').toString();
    final cardType = (card['cardType'] ?? '').toString();
    final estimatedSaving = (card['estimatedSaving'] as num?)?.toInt() ?? 0;
    final score = (card['score'] as num?)?.toInt() ?? 0;
    final matchedCategories = (card['matchedCategories'] as List?) ?? [];
    final benefitDetails = (card['benefitDetails'] as List?) ?? [];
    final appliedPromotions = (card['appliedPromotions'] as List?) ?? [];
    final reasonSummary = (card['reasonSummary'] ?? '').toString();

    final colors = _getCardPalette(bankName, title, matchedCategories);
    final icon = _getCardIcon(title, bankName, matchedCategories);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBadgeRow(rank, estimatedSaving, score, bankName),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: Color(0xFF212529),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_bankLabel(bankName)} · $cardType',
                        style: TextStyle(
                          color: colors[0],
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildMatchedCategoryText(matchedCategories),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildReasonBox(reasonSummary),
            if (benefitDetails.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoSection(
                title: '기본 혜택 분석',
                icon: Icons.insights_rounded,
                items: benefitDetails,
                color: const Color(0xFF1565C0),
              ),
            ],
            if (appliedPromotions.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoSection(
                title: '적용 프로모션',
                icon: Icons.local_offer_rounded,
                items: appliedPromotions,
                color: const Color(0xFFD81B60),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBadgeRow(int rank, int estimatedSaving, int score, String bankName) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'TOP $rank',
            style: const TextStyle(
              color: Color(0xFF4A00E0),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '예상 혜택 ${_formatWon(estimatedSaving)}',
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '추천 점수 $score',
            style: const TextStyle(
              color: Color(0xFFF57F17),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonBox(String reasonSummary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_rounded,
            color: Colors.amber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reasonSummary.isEmpty
                  ? '이번 달 소비 패턴을 기준으로 추천된 카드입니다.'
                  : reasonSummary,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<dynamic> items,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF212529),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}