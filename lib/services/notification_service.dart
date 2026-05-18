import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service managing local notifications and foreground service indicator.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification plugin and create the channel.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    await _createNotificationChannel();

    // Request permission on Android 13+
    await _requestPermissions();

    _initialized = true;
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'hermes_agent',
      'Hermes Agent',
      description: 'Notifications et statut du service Hermes Agent',
      importance: Importance.low,
      playSound: false,
      showBadge: true,
    );

    final flutterPlugin = FlutterLocalNotificationsPlugin();
    await flutterPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap — will be expanded in Phase 2
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Show a persistent foreground notification indicating service is running.
  Future<void> showForegroundNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'hermes_agent',
      'Hermes Agent',
      channelDescription: 'Notifications et statut du service Hermes Agent',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _foregroundNotificationId,
      title,
      body,
      details,
    );
  }

  /// Cancel the foreground notification.
  Future<void> cancelForegroundNotification() async {
    await _plugin.cancel(_foregroundNotificationId);
  }

  /// Show a notification for an incoming message.
  Future<void> showMessageNotification({
    required String content,
    String? sender,
  }) async {
    final title = sender ?? 'Hermes Agent';
    const maxLength = 200;
    final body = content.length > maxLength
        ? '${content.substring(0, maxLength)}…'
        : content;

    final androidDetails = AndroidNotificationDetails(
      'hermes_agent',
      'Hermes Agent',
      channelDescription: 'Notifications et statut du service Hermes Agent',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use timestamp to avoid overwriting previous notifications
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _plugin.show(id, title, body, details);
  }

  static final int _foregroundNotificationId = 0x1E55; // 7777
}
