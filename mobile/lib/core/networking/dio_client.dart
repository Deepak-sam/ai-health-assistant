import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Builds the single shared [Dio] instance used by every repository that
/// talks to the backend. Base URL and timeouts come from --dart-define
/// (AppConfig) — never hardcoded (hard constraint #8).
Dio buildDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: Duration(milliseconds: AppConfig.apiTimeoutMs),
      receiveTimeout: Duration(milliseconds: AppConfig.apiTimeoutMs),
      contentType: 'application/json',
    ),
  );
  dio.interceptors.add(AuthInterceptor());
  return dio;
}

/// Converts a [DioException] into the app's [ApiException], falling back to
/// a generic message when the backend didn't return the documented error
/// envelope (e.g. a network-level failure with no response body).
ApiException mapDioError(DioException err) {
  final data = err.response?.data;
  if (data is Map<String, dynamic>) {
    return ApiException.fromResponseBody(data, statusCode: err.response?.statusCode);
  }
  if (err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout ||
      err.type == DioExceptionType.connectionError) {
    return const ApiException(code: 'network_error', message: 'Could not reach the server. Check your connection.');
  }
  return ApiException(
    code: 'unknown_error',
    message: err.message ?? 'Something went wrong.',
    statusCode: err.response?.statusCode,
  );
}
