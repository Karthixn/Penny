class ApiConstants {
  static String get baseUrl {
    // Allow explicit override via --dart-define
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // Default to the 24/7 live cloud backend on Render
    return 'https://penny-37mv.onrender.com';
  }

  static const connectTimeout = Duration(seconds: 25);
  static const receiveTimeout = Duration(seconds: 25);
}
