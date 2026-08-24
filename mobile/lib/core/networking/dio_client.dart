import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'allowlist_state.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Riverpod-visible Dio client. Wires the allowlist-detection interceptor
/// (see [allowlistDetectionInterceptor]) on top of [buildDioClient] so any
/// repository built from this provider reports a `403 not_allowlisted`
/// straight into `notAllowlistedProvider`, which `AuthGate` watches.
final dioProvider = Provider<Dio>((ref) {
  final dio = buildDioClient();
  dio.interceptors.add(allowlistDetectionInterceptor(ref));
  return dio;
});

Interceptor allowlistDetectionInterceptor(Ref ref) {
  return InterceptorsWrapper(
    onError: (error, handler) {
      final data = error.response?.data;
      if (error.response?.statusCode == 403 &&
          data is Map<String, dynamic> &&
          (data['error'] as Map<String, dynamic>?)?['code'] == 'not_allowlisted') {
        ref.read(notAllowlistedProvider.notifier).state = true;
      }
      handler.next(error);
    },
  );
}

/// Builds a bare [Dio] instance. Base URL and timeouts come from
/// --dart-define (AppConfig) — never hardcoded (hard constraint #8). Prefer
/// [dioProvider] inside the widget tree; this is exposed directly for
/// contexts without a `Ref` (e.g. a plain constructor default).
Dio buildDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.apiTimeoutMs),
      receiveTimeout: const Duration(milliseconds: AppConfig.apiTimeoutMs),
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
