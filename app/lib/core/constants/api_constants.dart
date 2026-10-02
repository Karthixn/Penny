import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConstants {
  static String get baseUrl {
    // Allow explicit override via --dart-define
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Web runs on localhost
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    // Android devices use the host PC WiFi IP
    try {
      if (Platform.isAndroid) {
        return 'http://192.168.0.124:3000';
      }
    } catch (_) {
      // Fall through if platform check fails
    }

    return 'http://localhost:3000';
  }

  static const connectTimeout = Duration(seconds: 15);
  static const receiveTimeout = Duration(seconds: 15);
}
