import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // 프리미엄 알림 샘플 데이터
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': '🔥 맞춤 카드 추천 알림',
      'body': '회원님의 지난달 소비 패턴 분석이 완료되었습니다. 혜택이 가장 높은 추천 카드를 확인해보세요!',
      'time': '방금 전',
      'isRead': false,
      'icon': Icons.auto_awesome_rounded,
      'color': Colors.orangeAccent,
    },
    {
      'id': '2',
      'title': '⚠️ 이번 달 예산 소진 알림',
      'body': '설정하신 월간 예산의 80%를 사용하셨습니다. 계획적인 지출 관리가 필요합니다.',
      'time': '2시간 전',
      'isRead': false,
      'icon': Icons.pie_chart_rounded,
      'color': Colors.redAccent,
    },
    {
      'id': '3',
      'title': '☕ 스타벅스 50% 할인 혜택 시작',
      'body': '보유하신 카드의 특별 주말 혜택이 시작되었습니다. 놓치지 말고 혜택을 누리세요.',
      'time': '어제',
      'isRead': true,
      'icon': Icons.local_cafe_rounded,
      'color': Colors.brown,
    },
    {
      'id': '4',
      'title': '📊 월간 금융 리포트 도착',
      'body': '회원님의 자산 증감 및 카테고리별 상세 지출 리포트가 발행되었습니다.',
      'time': '3일 전',
      'isRead': true,
      'icon': Icons.insert_chart_rounded,
      'color': Colors.blueAccent,
    },
  ];

  void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('모든 알림을 읽음 처리했습니다.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeNotification(String id) {
    setState(() {
      _notifications.removeWhere((item) => item['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림 센터',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                '모두 읽음',
                style: TextStyle(
                  color: Color(0xFF4A00E0),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
                return _buildNotificationCard(item);
              },
            ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final bool isRead = item['isRead'];
    return Dismissible(
      key: Key(item['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => _removeNotification(item['id']),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : Colors.blue.shade50.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? Colors.transparent : const Color(0xFF4A00E0).withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() => item['isRead'] = true);
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item['icon'], color: item['color'], size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['title'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isRead ? FontWeight.w700 : FontWeight.w800,
                                  color: const Color(0xFF212529),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4A00E0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item['body'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.4,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item['time'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined, color: Colors.grey.shade400, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            '새로운 알림이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '금융 혜택 및 소비 리포트 알림이 이곳에 표시됩니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
