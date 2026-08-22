/// Env-driven configuration.
///
/// Everything here comes from `--dart-define` (or `--dart-define-from-file`)
/// at build time. Nothing secret is ever hardcoded in source, per
/// ARCHITECTURE.md's "no third-party analytics, TLS everywhere, minimal
/// secrets on device" posture and the task's hard constraint #8.
///
/// Example (see README.md for the full list):
///   flutter run \
///     --dart-define=API_BASE_URL=https://health-api.example.com/api/v1 \
///     --dart-define=GARMIN_ENABLED=false \
///     --dart-define=FIREBASE_WEB_API_KEY=... (only needed for web-style init;
///       native iOS/Android normally use GoogleService-Info.plist / google-services.json)
class AppConfig {
  AppConfig._();

  /// Base URL for the backend, e.g. `https://health-api.example.com/api/v1`.
  /// Must include the `/api/v1` prefix per API_SPEC.md.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  /// Feature flag gating the Garmin integration end to end (UI entry point,
  /// OAuth flow, sync). ARCHITECTURE.md §1/§6: Garmin ships behind a flag
  /// until Garmin Health API business approval is granted.
  static const bool garminEnabled = bool.fromEnvironment(
    'GARMIN_ENABLED',
    defaultValue: false,
  );

  /// When true, HealthProviders are backed by [FakeHealthProvider] with
  /// deterministic sample data instead of the real Health Connect / Garmin
  /// plugins. Useful for UI development without a device that has Health
  /// Connect data populated.
  static const bool useFakeHealthProvider = bool.fromEnvironment(
    'USE_FAKE_HEALTH_PROVIDER',
    defaultValue: true,
  );

  /// Backend endpoint the app opens (in a webview) to start the Garmin OAuth2
  /// PKCE flow. The backend owns the client secret and token exchange per
  /// ARCHITECTURE.md §6 — the app never sees the Garmin client secret.
  static const String garminAuthorizeUrl = String.fromEnvironment(
    'GARMIN_AUTHORIZE_URL',
    defaultValue: '',
  );

  /// Custom URL scheme the app registers to catch the end of the Garmin
  /// OAuth redirect chain (backend redirects here after completing the
  /// server-side token exchange).
  static const String garminRedirectScheme = String.fromEnvironment(
    'GARMIN_REDIRECT_SCHEME',
    defaultValue: 'familyhealth',
  );

  /// Request timeout for API calls, in milliseconds.
  static const int apiTimeoutMs = int.fromEnvironment(
    'API_TIMEOUT_MS',
    defaultValue: 20000,
  );
}
