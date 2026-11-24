// lib/screens/map_benefit_screen.dart
import 'package:flutter/material.dart';

class MapBenefitScreen extends StatefulWidget {
  const MapBenefitScreen({super.key});

  @override
  State<MapBenefitScreen> createState() => _MapBenefitScreenState();
}

class _MapBenefitScreenState extends State<MapBenefitScreen> {
  // 나중에 지도 API를 연동할 때 사용할 임시 카테고리 필터
  String _selectedCategory = '전체';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '주변 혜택 찾기',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, color: Colors.black87),
            onPressed: () {
              // 내 위치로 이동 기능
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. 임시 지도 배경 영역 (이곳에 Google Maps, Naver Map 등의 API 뷰가 들어갑니다)
          Container(
            color: const Color(0xFFE8ECEF),
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_rounded,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '여기에 지도 API가 렌더링됩니다.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. 임시 맵 마커 표시
          Positioned(
            top: 200,
            left: 150,
            child: _buildMapMarker(Icons.local_cafe_rounded, Colors.green),
          ),
          Positioned(
            top: 350,
            left: 250,
            child: _buildMapMarker(Icons.storefront_rounded, Colors.purple),
          ),
          Positioned(
            top: 280,
            left: 80,
            child: _buildMapMarker(Icons.restaurant_rounded, Colors.orange),
          ),

          // 3. 상단 카테고리 필터 칩
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: _buildCategoryChips(),
          ),

          // 4. 하단 주변 혜택 리스트 (Bottom Sheet 느낌)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildNearbyBenefitsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapMarker(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['전체', '카페', '편의점', '음식점', '주유'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF212529) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNearbyBenefitsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              '주변 혜택 가맹점',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF212529),
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                _buildBenefitTile(
                  storeName: '스타벅스 강남역점',
                  distance: '150m',
                  cardName: 'KB국민 청춘대로',
                  benefitText: '50% 청구할인',
                  icon: Icons.local_cafe_rounded,
                  iconColor: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildBenefitTile(
                  storeName: 'CU 서초대로점',
                  distance: '300m',
                  cardName: '신한 Mr.Life',
                  benefitText: '10% 캐시백',
                  icon: Icons.storefront_rounded,
                  iconColor: Colors.purple,
                ),
                const SizedBox(height: 12),
                _buildBenefitTile(
                  storeName: '맥도날드 양재점',
                  distance: '450m',
                  cardName: '현대카드 ZERO',
                  benefitText: '1.5% 기본할인',
                  icon: Icons.fastfood_rounded,
                  iconColor: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTile({
    required String storeName,
    required String distance,
    required String cardName,
    required String benefitText,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF212529),
                      ),
                    ),
                    Text(
                      distance,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cardName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      benefitText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A00E0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
