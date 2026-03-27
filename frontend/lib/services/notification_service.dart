// SmartDoz - Web Bildirim Servisi (EK1_revize.pdf Modül 2 & 7)
//
// Flutter Web'de browser Notification API'sini kullanarak
// ilaç hatırlatması gösterir.
//
// Mimari:
//   1. requestPermission() → tarayıcıdan bir kez izin ister
//   2. showDoseNotification() → yeni bir dose log bildirimi gösterir
//   3. _shownIds seti → aynı doz için tekrar bildirim gönderimini engeller
//   4. onclick handler → bildirime tıklanınca uygulama öne alınır
//
// NOT: "Uygulama kapalıyken bildirim" Flutter Web'de Service Worker
// + Web Push API gerektirir. Bu implementasyon uygulama açıkken
// (ama başka sekmede olduğunda) bildirimleri destekler.
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_tts/flutter_tts.dart';

// ── Web Notification API — dart:js_interop extension types ───────────

@JS('Notification')
extension type _JSNotif._(JSObject _) implements JSObject {
  external factory _JSNotif(String title, JSObject options);

  /// Mevcut izin durumu: 'granted' | 'denied' | 'default'
  external static String get permission;

  /// Tarayıcıdan bildirim izni ister (Promise döner, sonucu beklemeye gerek yok)
  external static JSPromise<JSString> requestPermission();

  /// Bildiriye tıklanınca çalışacak JS fonksiyonu
  external set onclick(JSFunction? fn);
}

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
  static Future<void> requestPermission() async {
    if (!kIsWeb || _permissionRequested) return;
    _permissionRequested = true;
    try {
      _JSNotif.requestPermission();
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
    if (!kIsWeb) return;
    if (_shownIds.contains(doseLogId)) return; // tekrar bildirimi engelle

    try {
      if (_JSNotif.permission != 'granted') return;

      // Seçenekler — JSObject üzerinden özellik ata (injection-safe: string literals)
      final opts = JSObject();
      opts.setProperty('body'.toJS, '⏰ Planlanan saat: $scheduledTime'.toJS);
      opts.setProperty('icon'.toJS, '/icons/Icon-192.png'.toJS);
      opts.setProperty('badge'.toJS, '/icons/Icon-192.png'.toJS);
      // tag: aynı ilaç için birden fazla bildirim yığılmasını engeller
      opts.setProperty('tag'.toJS, 'dose_$doseLogId'.toJS);
      opts.setProperty('requireInteraction'.toJS, false.toJS);

      final notif = _JSNotif('💊 İlaç Vakti: $medicationName', opts);

      // Tıklanınca uygulamanın açık olduğu sekmeyi öne al
      notif.onclick = (() {
        // ignore: undefined_prefixed_name
        try {
          // globalThis.window.focus() — dart:js_interop_unsafe ile
          globalContext.callMethod('focus'.toJS);
        } catch (_) {}
      }).toJS;

      _shownIds.add(doseLogId);

      // ── Sesli Bildirim (Modül 6) ─────────────────────────────────
      // Ekranda görünmeyen kullanıcıya TTS ile de hatırlatılır.
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
    if (!kIsWeb) return;
    try {
      if (_JSNotif.permission != 'granted') return;
      final opts = JSObject();
      opts.setProperty('body'.toJS, body.toJS);
      opts.setProperty('icon'.toJS, '/icons/Icon-192.png'.toJS);
      opts.setProperty('tag'.toJS, title.toJS);
      _JSNotif(title, opts);
    } catch (e) {
      debugPrint('[Notif] Bildirim gösterilemedi: $e');
    }
  }

  static String buildTitle(String medicationName) =>
      '💊 İlaç Vakti: $medicationName';

  static String buildBody(String scheduledTime) =>
      'Planlanan saat: $scheduledTime';
}

