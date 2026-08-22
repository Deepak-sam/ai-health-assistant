/// Mirrors the error envelope in API_SPEC.md:
/// `{"error": {"code": "not_allowlisted", "message": "..."}}`
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode});

  factory ApiException.fromResponseBody(Map<String, dynamic> body, {int? statusCode}) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return ApiException(
        code: error['code'] as String? ?? 'unknown_error',
        message: error['message'] as String? ?? 'Something went wrong.',
        statusCode: statusCode,
      );
    }
    return ApiException(code: 'unknown_error', message: 'Something went wrong.', statusCode: statusCode);
  }

  final String code;
  final String message;
  final int? statusCode;

  /// API_SPEC.md error codes: unauthorized (401), not_allowlisted (403),
  /// invalid_request (422), upstream_ai_error (502), rate_limited (429).
  bool get isNotAllowlisted => code == 'not_allowlisted';
  bool get isUnauthorized => code == 'unauthorized';
  bool get isRateLimited => code == 'rate_limited';

  @override
  String toString() => 'ApiException($code): $message';
}
