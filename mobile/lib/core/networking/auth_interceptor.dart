import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Attaches `Authorization: Bearer <firebase id token>` to every outgoing
/// request, per API_SPEC.md ("every endpoint except /health requires
/// Authorization: Bearer <Firebase ID token>"). The client never sends a
/// user_id in the body — identity is always derived server-side from this
/// token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      // forceRefresh: false — Firebase SDK caches and auto-refreshes tokens
      // internally; we only force a refresh reactively on a 401 (see below).
      final token = await user.getIdToken(false);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response?.statusCode == 401 && err.requestOptions.extra['retriedAfter401'] != true) {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        try {
          final freshToken = await user.getIdToken(true);
          final retryOptions = err.requestOptions
            ..headers['Authorization'] = 'Bearer $freshToken'
            ..extra['retriedAfter401'] = true;
          final dio = Dio()
            ..options.baseUrl = err.requestOptions.baseUrl
            ..options.connectTimeout = err.requestOptions.connectTimeout
            ..options.receiveTimeout = err.requestOptions.receiveTimeout;
          final response = await dio.fetch(retryOptions);
          return handler.resolve(response);
        } catch (_) {
          // Fall through to propagate the original error.
        }
      }
    }
    handler.next(err);
  }
}
