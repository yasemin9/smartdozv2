// SmartDoz - Bildirim Servisi (EK1_revize.pdf Modül 2 & 7)
//
// Flutter Web'de browser Notification API'sini kullanarak
// ilaç hatırlatması gösterir.
//
// Mimari:
//   1. requestPermission() → tarayıcıdan bir kez izin ister (web only)
//   2. showDoseNotification() → yeni bir dose log bildirimi gösterir
//   3. _shownIds seti → aynı doz için tekrar bildirim gönderimini engeller
//   4. onclick handler → bildirime tıklanınca uygulama öne alınır (web only)
//
// NOT: dart:js_interop web-only kütüphane. Mobile build'lerinde bu
// service sadece TTS/log için kullanılır (bildirim UI yoktur).

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// ── SmartDoz Bildirim Servisi ─────────────────────────────────────────

class NotificationService {
  /// Oturum boyunca bildirim gönderilmiş doz log ID'leri.
  static final _shownIds = <int>{};
  static final _shownCaregiverNotificationIds = <int>{};

  static bool _permissionRequested = false;
  static bool _initialized = false;

  // ── Push Notifications (Mobile) ────────────────────────────────
  static late FlutterLocalNotificationsPlugin _notificationsPlugin;

  // ── TTS (Modül 6 entegrasyonu) ─────────────────────────────────────
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsReady = false;

  // ── Initialization ─────────────────────────────────────────────

  /// Notification action callback (global scope)
  static Function(String? payload, String actionId)? onNotificationAction;

  /// Notification plugin'i başlat (mobile + web)
  static Future<void> init({
    Function(String? payload, String actionId)? onAction,
  }) async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      debugPrint('[Notif] Web platform - local notifications skip');
      return;
    }

    // Mobile: Local notifications
    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint(
            '[Notif] Action: ${response.actionId}, Payload: ${response.payload}');
        onNotificationAction?.call(response.payload, response.actionId ?? '');
      },
    );

    if (onAction != null) {
      onNotificationAction = onAction;
    }
    debugPrint('[Notif] Local notifications initialized with action handler');
  }

  static Future<void> _ensureTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    _ttsReady = true;
  }

  /// Bildirim sesini sesli olarak okur (TTS).
  /// VoiceController'dan bağımsız çalışır — bildirim polling'i tetikler.
  static Future<void> announceViaTts({
    required String medicationName,
    required String scheduledTime,
  }) async {
    await _ensureTts();
    await _tts.stop();
    await _tts.speak(
      '$medicationName ilacınızı alma zamanı geldi. '
      'Planlanan saat: $scheduledTime.',
    );
  }

  // ── İzin ─────────────────────────────────────────────────────────

  /// İşletim sisteminden bildirim izni ister (permission_handler paketi ile)
  static Future<bool> requestPermission() async {
    if (kIsWeb) return true;

    if (_permissionRequested) return true;
    _permissionRequested = true;

    // Android 13+ ve iOS: Notification izni iste
    final status = await Permission.notification.request();

    final granted = status.isGranted || status.isDenied;
    debugPrint('[Notif] Notification permission: $status');

    return granted;
  }

  // ── Push Notification gösterme ────────────────────────────────

  /// Atlanmış ilaç bildirimi göster (sistem tray) — action butonları ile
  static Future<void> showMissedDoseNotification({
    required int doseLogId,
    required String medicationName,
    required String userName,
    required String scheduledTime,
  }) async {
    if (_shownIds.contains(doseLogId)) return;

    if (kIsWeb) {
      debugPrint('[Notif] Web: Missed dose notification (web only shows TTS)');
      await announceViaTts(
        medicationName: medicationName,
        scheduledTime: scheduledTime,
      );
      _shownIds.add(doseLogId);
      return;
    }

    final String title = 'Ilac vakti: $medicationName';
    final String body =
        '$userName icin $scheduledTime saatli doz zamani geldi.';

    // Payload: doz bilgisi (JSON string olarak)
    final String payload = '$doseLogId|$medicationName|$scheduledTime';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'smartdoz_dose_alerts_v2',
      'Ilac Hatirlaticilari',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      ticker: 'Ilac vakti',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'took',
          'Aldım',
          titleColor: Color.fromARGB(255, 46, 125, 50), // green
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'skipped',
          'Almadım',
          titleColor: Color.fromARGB(255, 198, 40, 40), // red
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze',
          '10 dk ertele',
          titleColor: Color.fromARGB(255, 230, 81, 0), // orange
          showsUserInterface: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'missed_dose_thread',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      doseLogId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    _shownIds.add(doseLogId);
    debugPrint('[Notif] Missed dose shown: $medicationName (ID: $doseLogId)');
  }

  /// Bakici hesabina dusen backend bildirimini sistem tepsisinde gosterir.
  static Future<void> showCaregiverNotification({
    required int notificationId,
    required String title,
    required String body,
  }) async {
    if (_shownCaregiverNotificationIds.contains(notificationId)) return;
    _shownCaregiverNotificationIds.add(notificationId);

    if (kIsWeb) {
      debugPrint('[Notif] Web caregiver notification: $title - $body');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'smartdoz_caregiver_alerts_v2',
      'Bakici Bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      ticker: 'SmartDoz Bakici Bildirimi',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'caregiver_alerts_thread',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      100000 + notificationId,
      title,
      body,
      notificationDetails,
      payload: 'caregiver|$notificationId',
    );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool enableVibration = true,
    bool enableSound = true,
  }) async {
    if (kIsWeb) {
      debugPrint('[Notif] Web: $title - $body');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'smartdoz_general_v2',
      'SmartDoz Bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );

    debugPrint('[Notif] Notification shown: $title');
  }

  // ── Bildirim iptaline ────────────────────────────────────────

  /// Belirli bir bildirim ID'sini iptal et
  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id);
      debugPrint('[Notif] Cancelled: $id');
    } catch (e) {
      debugPrint('[Notif] Cancel failed: $e');
    }
  }

  /// Tüm bildirimleri iptal et
  static Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint('[Notif] All notifications cancelled');
    } catch (e) {
      debugPrint('[Notif] Cancel all failed: $e');
    }
  }

  // ── Yeni Doz Bildirimi (Eski sistem - Web + TTS uyumlu) ─────────

  /// Backend /notifications/pending endpoint'inden gelen dozlar için bildirim.
  /// Aynı [doseLogId] için tekrar bildirim göstermez.
  /// Erteleme sonrası aynı doz için re-notification sağlamak amacıyla
  /// ID'yi shown listesinden temizler.
  static void clearId(int doseLogId) => _shownIds.remove(doseLogId);

  static void showDoseNotification({
    required int doseLogId,
    required String medicationName,
    required String scheduledTime,
  }) {
    if (_shownIds.contains(doseLogId)) return; // tekrar bildirimi engelle

    _shownIds.add(doseLogId);

    if (!kIsWeb) {
      // Android/iOS: TTS bildirim
      debugPrint('[Notif] Mobile: $medicationName - $scheduledTime');
      announceViaTts(
        medicationName: medicationName,
        scheduledTime: scheduledTime,
      ).ignore();
      return;
    }

    // Web: Bildirim + TTS (browser Notification API)
    try {
      debugPrint('[Notif] Web: $medicationName - $scheduledTime');
      announceViaTts(
        medicationName: medicationName,
        scheduledTime: scheduledTime,
      ).ignore();
    } catch (e) {
      debugPrint('[Notif] Bildirim gösterilemedi: $e');
    }
  }

  // ── Legacy compat (DashboardTab eski kodundan çağrılıyor) ─────────

  /// Başlık + gövde ile doğrudan bildirim gösterir.
  static void show(String title, String body) {
    try {
      debugPrint('[Notif] $title: $body');
      if (!kIsWeb) return; // Mobile'de sadece log

      // Web'de bildirim göster
      debugPrint('[Notif] Web notification: $title');
    } catch (e) {
      debugPrint('[Notif] Bildirim gösterilemedi: $e');
    }
  }

  static String buildTitle(String medicationName) =>
      '💊 İlaç Vakti: $medicationName';

  static String buildBody(String scheduledTime) =>
      'Planlanan saat: $scheduledTime';
}
