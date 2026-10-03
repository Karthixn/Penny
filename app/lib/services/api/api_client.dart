import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  VoidCallback? onUnauthenticated;
  Completer<bool>? _refreshCompleter;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          // Don't attempt to refresh if the error came from auth endpoints
          if (path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh')) {
            return handler.next(error);
          }

          final refreshed = await _refreshToken();
          if (refreshed) {
            try {
              final retryResponse = await _retry(error.requestOptions);
              return handler.resolve(retryResponse);
            } catch (retryError) {
              if (retryError is DioException) {
                return handler.next(retryError);
              }
            }
          } else {
            onUnauthenticated?.call();
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    // If a refresh is already in flight, wait for it instead of sending duplicate requests
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        completer.complete(false);
        _refreshCompleter = null;
        return false;
      }

      final response = await Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
      )).post('/auth/refresh', data: {'refreshToken': refreshToken});

      final data = response.data as Map<String, dynamic>;
      if (data['accessToken'] != null && data['refreshToken'] != null) {
        await SecureStorage.saveTokens(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
        completer.complete(true);
        _refreshCompleter = null;
        return true;
      } else {
        await SecureStorage.clearTokens();
        completer.complete(false);
        _refreshCompleter = null;
        return false;
      }
    } catch (_) {
      await SecureStorage.clearTokens();
      completer.complete(false);
      _refreshCompleter = null;
      return false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    // Get the fresh token after refresh — don't reuse the old headers
    final freshToken = await SecureStorage.getAccessToken();
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (freshToken != null) {
      headers['Authorization'] = 'Bearer $freshToken';
    }

    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: Options(
        method: requestOptions.method,
        headers: headers,
      ),
    );
  }
}
