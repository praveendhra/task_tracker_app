import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Web Push needs the project's public VAPID key
/// (Firebase console > Project settings > Cloud Messaging > Web Push certificates).
/// CI passes it with --dart-define=FCM_VAPID_KEY=...
const kVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Gets this device's push token so the server can send reminders.
abstract class PushService {
  /// Whether push can work on this platform/build at all.
  bool get supported;

  /// Asks for permission if needed and returns this device's token, or null
  /// if the user declined or it isn't available.
  Future<String?> register();

  /// This device's current token without prompting (null if not permitted).
  Future<String?> currentToken();

  /// Forgets this device's token so it stops receiving reminders.
  Future<void> unregister();

  /// New tokens when the platform rotates them.
  Stream<String> get tokenRefresh;
}

class FirebasePushService implements PushService {
  FirebasePushService([FirebaseMessaging? messaging])
      : _m = messaging ?? FirebaseMessaging.instance;
  final FirebaseMessaging _m;

  @override
  bool get supported {
    if (kIsWeb) return kVapidKey.isNotEmpty;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<String?> _token() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // FCM needs the APNs token first; it can take a moment after launch.
        for (var i = 0; i < 10 && await _m.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      return await _m.getToken(vapidKey: kIsWeb ? kVapidKey : null);
    } catch (e) {
      debugPrint('Push token unavailable: $e');
      return null;
    }
  }

  bool _allowed(NotificationSettings s) =>
      s.authorizationStatus == AuthorizationStatus.authorized ||
      s.authorizationStatus == AuthorizationStatus.provisional;

  @override
  Future<String?> register() async {
    if (!supported) return null;
    final s = await _m.requestPermission(alert: true, badge: true, sound: true);
    if (!_allowed(s)) return null;
    return _token();
  }

  @override
  Future<String?> currentToken() async {
    if (!supported) return null;
    final s = await _m.getNotificationSettings();
    return _allowed(s) ? _token() : null;
  }

  @override
  Future<void> unregister() async {
    if (!supported) return;
    try {
      await _m.deleteToken();
    } catch (e) {
      debugPrint('Could not delete push token: $e');
    }
  }

  @override
  Stream<String> get tokenRefresh => supported ? _m.onTokenRefresh : const Stream.empty();
}

/// Used by the demo build and tests.
class FakePushService implements PushService {
  FakePushService({this.supported = true, this.grant = true});
  @override
  final bool supported;
  final bool grant;
  String? _token;

  @override
  Future<String?> register() async => _token = grant ? 'demo-token' : null;
  @override
  Future<String?> currentToken() async => _token;
  @override
  Future<void> unregister() async => _token = null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
}
