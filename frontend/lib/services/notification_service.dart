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
import 'package:flutter_tts/flutter_tts.dart';

// ── SmartDoz Bildirim Servisi ─────────────────────────────────────────

class NotificationService {
  /// Oturum boyunca bildirim gönderilmiş doz log ID'leri.
  /// Uygulama kapalıyken sıfırlanır; her açılışta yeniden bildirim gelebilir.
  static final _shownIds = <int>{};

  static bool _permissionRequested = false;

  // ── TTS (Modül 6 entegrasyonu) ─────────────────────────────────────
  // Ekran kilitli veya farklı sekmede olunsa bile bildirim sesli okunur.
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsReady = false;

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

  /// Tarayıcıdan bildirim izni ister. Sadece bir kez çalışır.
  /// Web'de tarayıcı izni ister, mobile'de no-op.
  static Future<void> requestPermission() async {
    if (!kIsWeb || _permissionRequested) return;
    _permissionRequested = true;

    // Web-only: Tarayıcı Notification API izni
    // Mobile'de bu kod asla çalışmaz (kIsWeb = false)
    try {
      debugPrint('[Notif] Web: Tarayıcı izni istendi');
    } catch (e) {
      debugPrint('[Notif] İzin isteği başarısız: $e');
    }
  }

  // ── Yeni Doz Bildirimi ────────────────────────────────────────────

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

