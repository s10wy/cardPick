import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/ledger_screen.dart' show Transaction;
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardRecommendationApp());
}

class CardRecommendationApp extends StatelessWidget {
  const CardRecommendationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '카드픽',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A00E0)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CardHomeScreen extends StatefulWidget {
  const CardHomeScreen({super.key});

  @override
  State<CardHomeScreen> createState() => _CardHomeScreenState();
}

class _CardHomeScreenState extends State<CardHomeScreen> {
  late Future<Map<String, dynamic>?> _assetsFuture;

  @override
  void initState() {
    super.initState();
    _assetsFuture = _loadAllAssets();
  }

  Future<void> _refreshAssets() async {
    ApiService.clearCache();
    setState(() {
      _assetsFuture = _loadAllAssets();
    });
    await _assetsFuture;
  }

  Future<Map<String, dynamic>?> _loadAllAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');

    if (email == null || email.isEmpty) {
      return null;
    }

    final assets = await ApiService.fetchIntegratedAssets(email);
    if (assets == null) {
      return null;
    }

    final dbTransactions = await ApiService.fetchCurrentMonthTransactions(email);

    assets['db_transactions'] = dbTransactions;

    debugPrint('HOME assets = $assets');
    debugPrint('HOME accounts = ${assets['accounts']}');
    debugPrint(
      'HOME total balance = ${assets['total_balance'] ?? assets['totalBalance'] ?? assets['totalbalance'] ?? assets['balance']}',
    );
    debugPrint(
      'HOME registered cards = ${assets['my_registered_cards'] ?? assets['myRegisteredCards'] ?? assets['myregisteredcards']}',
    );
    debugPrint(
      'HOME bank cards = ${assets['available_bank_cards'] ?? assets['availableBankCards'] ?? assets['availablebankcards'] ?? assets['cards']}',
    );

    return assets;
  }

  String _formatCurrency(num amount) {
    return amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '내 자산',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.black87,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _assetsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 100.0),
                child: CircularProgressIndicator(color: Color(0xFF4A00E0)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  '데이터를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.data == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _goToLogin();
            });
            return const SizedBox.shrink();
          }

          final assets = snapshot.data ?? <String, dynamic>{};

          final userName = (assets['user_name'] ??
                  assets['userName'] ??
                  assets['username'] ??
                  assets['name'] ??
                  '고객')
              .toString();

          final totalBalance = _toNum(
            assets['total_balance'] ??
                assets['totalBalance'] ??
                assets['totalbalance'] ??
                assets['balance'] ??
                0,
          );

          final accounts = _toMapList(
            assets['accounts'] ?? assets['account_list'] ?? assets['accountList'],
          );

          final regCards = _toMapList(
            assets['my_registered_cards'] ??
                assets['myRegisteredCards'] ??
                assets['myregisteredcards'],
          );

          final bankCards = _toMapList(
            assets['available_bank_cards'] ??
                assets['availableBankCards'] ??
                assets['availablebankcards'] ??
                assets['cards'],
          );

          final allCards = [...regCards, ...bankCards];

          final dbTransactions =
              (assets['db_transactions'] is List<Transaction>)
                  ? assets['db_transactions'] as List<Transaction>
                  : <Transaction>[];

          return RefreshIndicator(
            onRefresh: _refreshAssets,
            color: const Color(0xFF4A00E0),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$userName님\n오늘도 좋은 하루 되세요!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        letterSpacing: -0.5,
                        color: Color(0xFF212529),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '내 계좌',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF212529),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAccountInfo(accounts, totalBalance),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '내 카드',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212529),
                          ),
                        ),
                        Text(
                          '관리',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMyCardsList(allCards),
                    const SizedBox(height: 36),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이번 달 소비 내역',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF212529),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: Text(
                            '더보기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTransactionsSection(dbTransactions),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountInfo(List<Map<String, dynamic>> accounts, num totalBalance) {
    String accountTitle = '통합 계좌 잔액';

    if (accounts.isNotEmpty) {
      final firstAcc = accounts.first;
      final bankOrigin = (firstAcc['bank_origin'] ??
              firstAcc['bankOrigin'] ??
              firstAcc['bankorigin'] ??
              '')
          .toString();
      final accName = (firstAcc['account_name'] ??
              firstAcc['accountName'] ??
              firstAcc['accountname'] ??
              firstAcc['name'] ??
              '주거래 통장')
          .toString();

      accountTitle = '$bankOrigin $accName'.trim();
    } else if (totalBalance == 0) {
      accountTitle = '연동된 계좌가 없습니다';
    }

    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  accountTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatCurrency(totalBalance)} 원',
            style: const TextStyle(
              color: Color(0xFF212529),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransferScreen(
                          currentBalance: totalBalance,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F3F5),
                    foregroundColor: const Color(0xFF212529),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '이체',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F3F5),
                    foregroundColor: const Color(0xFF212529),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '결제',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyCardsList(List<Map<String, dynamic>> cards) {
    if (cards.isEmpty) {
      return Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off_rounded,
              color: Colors.grey.shade300,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              '등록된 카드가 없습니다.',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final palettes = [
      [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)],
      [const Color(0xFF111111), const Color(0xFF333333)],
      [const Color(0xFFFFB75E), const Color(0xFFED8F03)],
      [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
      [const Color(0xFFFF5858), const Color(0xFFF09819)],
    ];

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];

          final name = (card['cardName'] ??
                  card['card_name'] ??
                  card['cardname'] ??
                  card['name'] ??
                  '알 수 없는 카드')
              .toString();

          final rawNumber = (card['cardNumber'] ??
                  card['card_number'] ??
                  card['cardnumber'] ??
                  card['number'] ??
                  '****')
              .toString();

          final type = (card['cardType'] ??
                  card['card_type'] ??
                  card['cardtype'] ??
                  card['type'] ??
                  '카드')
              .toString();

          final bankOrigin = (card['bank_origin'] ??
                  card['bankOrigin'] ??
                  card['bankorigin'] ??
                  '')
              .toString();

          final displayName = '$bankOrigin $name'.trim();
          final displayNumber = _maskCardNumber(rawNumber);

          final colors = palettes[index % palettes.length];

          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              type,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.contactless_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        displayNumber,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          letterSpacing: 2,
                          fontFamily: 'Courier',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _maskCardNumber(String number) {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length >= 16) {
      return '${digits.substring(0, 4)} ${digits.substring(4, 8)} ${digits.substring(8, 12)} ${digits.substring(12, 16)}';
    }

    if (digits.length >= 4) {
      return '**** **** **** ${digits.substring(digits.length - 4)}';
    }

    return number;
  }

  Widget _buildTransactionsSection(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            '이번 달 거래 내역이 없습니다.',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
          ),
        ),
      );
    }

    final recentList = transactions.take(3).toList();

    String formatDate(DateTime date) {
      final now = DateTime.now();
      final difference = DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(date.year, date.month, date.day)).inDays;

      if (difference == 0) {
        return '오늘 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      if (difference == 1) {
        return '어제 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: recentList.map((tx) {
          final isLast = tx == recentList.last;
          return Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tx.iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(tx.icon, color: tx.iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF212529),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(tx.date),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${tx.isExpense ? "-" : "+"}${_formatCurrency(tx.amount)}원',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: tx.isExpense
                          ? const Color(0xFF212529)
                          : const Color(0xFF42A5F5),
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.grey.shade100, height: 1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}