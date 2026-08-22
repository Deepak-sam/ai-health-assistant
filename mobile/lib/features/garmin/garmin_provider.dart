import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/routing/navigator_key.dart';
import '../../core/security/secure_token_storage.dart';
import '../health/health_provider.dart';
import '../health/models/health_models.dart' as domain;
import 'garmin_oauth_webview_screen.dart';

/// `HealthProvider` implementation for Garmin Connect, gated end-to-end
/// behind [AppConfig.garminEnabled] (ARCHITECTURE.md §1/§6 Decision: ships
/// as a working OAuth + REST client while Garmin Health API business
/// approval is pending, so the rest of the app isn't blocked on it).
///
/// OAuth2 PKCE happens **server-side**: this class never generates a code
/// verifier/challenge and never sees Garmin's client secret. It opens a
/// webview to a backend-provided authorization URL; Garmin redirects to the
/// *backend's* registered callback (not this app), the backend completes
/// the token exchange, and finally redirects the webview to this app's
/// custom URL scheme with a short-lived session reference.
///
/// Data-fetching methods (`getDailySummary`/`getSleep`/etc.) are
/// intentionally unimplemented in Phase 1: API_SPEC.md does not yet define
/// a backend endpoint that proxies real Garmin metrics to the device (the
/// backend has "no health-metric database" per ARCHITECTURE.md §2, and
/// Garmin data-sync isn't in the Phase 1 backend roadmap). Rather than
/// fabricate data, these throw — see README.md "Garmin OAuth notes" for
/// what the backend needs to add before this is functionally complete.
class GarminProvider implements HealthProvider {
  GarminProvider({required Dio dio, required SecureTokenStorage tokenStorage})
      : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  @override
  String get providerId => 'garmin';

  @override
  Future<bool> isConnected() async => (await _tokenStorage.readGarminSessionRef()) != null;

  @override
  Future<void> connect() async {
    final authorizeUrl = await _fetchAuthorizeUrl();
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      throw StateError('No navigator available to present the Garmin sign-in screen.');
    }
    final redirectUri = await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) => GarminOAuthWebViewScreen(
          authorizeUrl: authorizeUrl,
          redirectScheme: AppConfig.garminRedirectScheme,
        ),
        fullscreenDialog: true,
      ),
    );
    if (redirectUri == null) {
      throw StateError('Garmin connection was cancelled.');
    }

    final uri = Uri.parse(redirectUri);
    final status = uri.queryParameters['status'];
    final sessionRef = uri.queryParameters['session_ref'];
    if (status != 'connected' || sessionRef == null) {
      throw StateError(uri.queryParameters['error'] ?? 'Garmin connection failed.');
    }
    await _tokenStorage.saveGarminSessionRef(sessionRef);
  }

  Future<String> _fetchAuthorizeUrl() async {
    if (AppConfig.garminAuthorizeUrl.isNotEmpty) {
      // Dev/testing override — a statically configured URL instead of a
      // fresh backend-minted one.
      return AppConfig.garminAuthorizeUrl;
    }
    // NOT YET IN API_SPEC.md — documented assumption (see README.md): the
    // backend must expose an authenticated endpoint that mints a one-time
    // authorize URL with a server-generated PKCE challenge + state stored
    // server-side, keyed to the caller's verified Firebase identity.
    final response = await _dio.get<Map<String, dynamic>>('/garmin/oauth/authorize-url');
    final url = response.data?['authorize_url'] as String?;
    if (url == null) {
      throw StateError('Backend did not return a Garmin authorize URL.');
    }
    return url;
  }

  @override
  Future<void> disconnect() async {
    await _tokenStorage.clearGarminSessionRef();
  }

  @override
  Future<domain.SyncResult> sync({DateTime? since}) async {
    if (!await isConnected()) {
      return domain.SyncResult(providerId: providerId, success: false, error: 'Not connected.');
    }
    // See class doc: no backend data-sync endpoint exists yet. Reporting a
    // zero-metric success (rather than throwing) keeps SyncService's
    // "sync everything connected" loop well-behaved without pretending to
    // have live Garmin data.
    return domain.SyncResult(providerId: providerId, success: true, metricsSynced: 0, syncedAt: DateTime.now());
  }

  @override
  Future<domain.DailySummary> getDailySummary(DateTime date) => _notImplemented();

  @override
  Future<List<domain.SleepSession>> getSleep(domain.DateRange range) => _notImplemented();

  @override
  Future<List<domain.HeartRateSample>> getHeartRate(domain.DateRange range) => _notImplemented();

  @override
  Future<List<domain.Activity>> getActivities(domain.DateRange range) => _notImplemented();

  @override
  Future<List<domain.HealthMetric>> getMetrics(String metricType, domain.DateRange range) => _notImplemented();

  Never _notImplemented() {
    throw UnimplementedError(
      'Garmin data sync is not available in Phase 1 — the backend has no '
      'Garmin metrics endpoint yet. Only OAuth connection status is available.',
    );
  }
}
