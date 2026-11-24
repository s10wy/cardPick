// lib/services/api_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../screens/ledger_screen.dart';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Map<String, dynamic>? assetsCache;
  static List<Transaction>? txCache;
  static List<dynamic>? cardsCache;
  static List<dynamic>? recommendedCardsCache;
  static DateTime? cacheTime;

  static const cacheTtl = Duration(minutes: 5);

  static bool get isCacheValid =>
      cacheTime != null && DateTime.now().difference(cacheTime!) < cacheTtl;

  static void clearCache() {
    assetsCache = null;
    txCache = null;
    cardsCache = null;
    recommendedCardsCache = null;
    cacheTime = null;
  }

  static String normalizeCategory(String? category) {
    final value = (category ?? '').toString().trim().toUpperCase();

    switch (value) {
      case '카페':
      case 'CAFE':
        return 'CAFE';

      case '쇼핑':
      case 'SHOPPING':
      case 'MART':
        return 'SHOPPING';

      case '교통':
      case 'TRANSPORT':
      case 'TRANSPORTATION':
        return 'TRANSPORT';

      case '식비':
      case 'FOOD':
        return 'FOOD';

      case '구독':
      case '취미':
      case 'HOBBY':
      case 'CULTURE':
        return 'HOBBY';

      case '편의점':
      case 'CONVENIENCE':
        return 'CONVENIENCE';

      case '주유':
      case 'OIL':
        return 'OIL';

      case '뷰티':
      case 'BEAUTY':
        return 'BEAUTY';

      case '급여':
      case 'DEPOSIT':
        return 'DEPOSIT';

      default:
        return category?.toString() ?? '기타';
    }
  }

  static IconData getIconForCategory(String? category) {
    switch (normalizeCategory(category)) {
      case 'CAFE':
        return Icons.local_cafe_rounded;

      case 'SHOPPING':
        return Icons.shopping_basket_rounded;

      case 'TRANSPORT':
        return Icons.directions_car_rounded;

      case 'FOOD':
        return Icons.restaurant_rounded;

      case 'HOBBY':
        return Icons.movie_rounded;

      case 'CONVENIENCE':
        return Icons.storefront_rounded;

      case 'OIL':
        return Icons.local_gas_station_rounded;

      case 'BEAUTY':
        return Icons.face_retouching_natural_rounded;

      case 'DEPOSIT':
        return Icons.monetization_on_rounded;

      default:
        return Icons.payment_rounded;
    }
  }

  static Color getColorForCategory(String? category) {
    switch (normalizeCategory(category)) {
      case 'CAFE':
        return const Color(0xFF8D6E63);

      case 'SHOPPING':
        return const Color(0xFF66BB6A);

      case 'TRANSPORT':
        return const Color(0xFFFFCA28);

      case 'FOOD':
        return const Color(0xFFFF7043);

      case 'HOBBY':
        return const Color(0xFFEF5350);

      case 'CONVENIENCE':
        return const Color(0xFF26A69A);

      case 'OIL':
        return const Color(0xFF5C6BC0);

      case 'BEAUTY':
        return const Color(0xFFAB47BC);

      case 'DEPOSIT':
        return const Color(0xFF42A5F5);

      default:
        return const Color(0xFF9E9E9E);
    }
  }

  static Future<Map<String, dynamic>?> fetchIntegratedAssets(String email) async {
    if (isCacheValid && assetsCache != null) return assetsCache;

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/integrated-assets/$email'))
          .timeout(const Duration(seconds: 10));

      debugPrint('fetchIntegratedAssets status: ${response.statusCode}');
      debugPrint('fetchIntegratedAssets body: ${response.body}');

      if (response.statusCode == 200) {
        assetsCache = json.decode(response.body) as Map<String, dynamic>;
        cacheTime = DateTime.now();
        return assetsCache;
      }

      return null;
    } catch (e) {
      debugPrint('fetchIntegratedAssets error: $e');
      return null;
    }
  }

  static Future<List<Transaction>> fetchCurrentMonthTransactions(String email) async {
    if (isCacheValid && txCache != null) return txCache!;

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/transactions/current-month/$email'))
          .timeout(const Duration(seconds: 10));

      debugPrint('fetchCurrentMonthTransactions status: ${response.statusCode}');
      debugPrint('fetchCurrentMonthTransactions body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;

        txCache = data.map((item) {
          final amount = item['amount'] is num
              ? (item['amount'] as num).toInt()
              : int.tryParse(item['amount'].toString()) ?? 0;

          final rawType = (item['transactionType'] ??
                  item['transaction_type'] ??
                  '')
              .toString()
              .trim()
              .toUpperCase();

          final rawCategory = item['category']?.toString();
          final normalizedCategory = normalizeCategory(rawCategory);

          final isExpense = !(rawType == 'DEPOSIT' ||
              rawType == 'IN' ||
              rawType == 'INCOME' ||
              rawType == 'CREDIT' ||
              rawType == '입금');

          final rawDate = item['createdAt'] ?? item['created_at'];
          DateTime parsedDate;
          try {
            parsedDate = rawDate != null
                ? DateTime.parse(rawDate.toString())
                : DateTime.now();
          } catch (_) {
            parsedDate = DateTime.now();
          }

          return Transaction(
            title: item['description'] ??
                item['toAccount'] ??
                item['to_account'] ??
                '거래 내역',
            category: normalizedCategory,
            date: parsedDate,
            amount: amount,
            isExpense: isExpense,
            icon: getIconForCategory(normalizedCategory),
            iconColor: getColorForCategory(normalizedCategory),
          );
        }).toList();

        cacheTime ??= DateTime.now();
        return txCache!;
      }

      return [];
    } catch (e) {
      debugPrint('fetchCurrentMonthTransactions error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> fetchAllCards() async {
    if (isCacheValid && cardsCache != null) return cardsCache!;

    try {
      final response = await http
          .get(Uri.parse('$baseUrl/cards/all'))
          .timeout(const Duration(seconds: 10));

      debugPrint('fetchAllCards status: ${response.statusCode}');
      debugPrint('fetchAllCards body: ${response.body}');

      if (response.statusCode == 200) {
        cardsCache = json.decode(response.body) as List<dynamic>;
        cacheTime ??= DateTime.now();
        return cardsCache!;
      }

      return [];
    } catch (e) {
      debugPrint('fetchAllCards error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> fetchRecommendedCards(String email) async {
  try {
    final response = await http
        .get(Uri.parse('$baseUrl/cards/recommendation/$email'))
        .timeout(const Duration(seconds: 10));

    debugPrint('fetchRecommendedCards status: ${response.statusCode}');
    debugPrint('fetchRecommendedCards body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return (data['recommendedCards'] as List?) ?? [];
    }

    return [];
  } catch (e) {
    debugPrint('fetchRecommendedCards error: $e');
    return [];
  }
  }
}