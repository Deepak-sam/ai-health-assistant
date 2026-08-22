import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps FCM registration/handling (push, e.g. a server-triggered nudge —
/// ARCHITECTURE.md's `/notifications/send` — though that backend endpoint
/// isn't in the current API_SPEC.md; token upload is a TODO for whoever
/// adds it) and local notifications (used by `AlertRuleEvaluator` to
/// surface an on-device rule breach immediately, without any network
/// round-trip — ARCHITECTURE.md §10).
class NotificationService {
  NotificationService({FirebaseMessaging? messaging, FlutterLocalNotificationsPlugin? local})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _local = local ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  static const _androidChannel = AndroidNotificationChannel(
    'health_alerts',
    'Health alerts',
    description: 'Notifications when one of your alert rules fires.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  /// Requests push permission and returns the FCM registration token, or
  /// null if the user declined. Uploading this token to the backend
  /// requires an endpoint not yet defined in API_SPEC.md.
  Future<String?> registerForPush() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return null;
    return _messaging.getToken();
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  void listenForegroundMessages(void Function(RemoteMessage message) onMessage) {
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  void listenMessageOpenedApp(void Function(RemoteMessage message) onOpened) {
    FirebaseMessaging.onMessageOpenedApp.listen(onOpened);
  }

  /// Shows an immediate on-device notification for a fired alert rule.
  /// Called by `AlertRuleEvaluator`'s caller after a rule breach is
  /// detected — the evaluator itself stays pure/deterministic and does not
  /// touch plugins directly.
  Future<void> showAlertNotification({required int id, required String title, required String body}) {
    return _local.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_alerts',
          'Health alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
