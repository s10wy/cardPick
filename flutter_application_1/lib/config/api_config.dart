// lib/config/api_config.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // true = 실제 Android 기기, false = Android 에뮬레이터
  static const bool useRealDevice = false;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (Platform.isAndroid) {
      if (useRealDevice) {
        // 실제 Android 기기: PC와 같은 Wi-Fi 네트워크에 연결 필요
        return 'http://192.168.50.217:8080';
      } else {
        // Android 에뮬레이터: 에뮬레이터에서 host PC를 가리키는 주소
        return 'http://10.0.2.2:8080';
      }
    }
    // iOS 시뮬레이터, Windows, Mac, Linux
    return 'http://localhost:8080';
  }
}
