// SmartDoz - Sesli Asistan Kontrolcüsü (Modül 6)
//
// ── Mimari ───────────────────────────────────────────────────────────────────
//   STT  : speech_to_text  (Web Speech API, Chrome uyumlu)
//   TTS  : flutter_tts     (Web Speech Synthesis, çevrimdışı çalışır)
//   Mod1 : Groq Llama 3.1 üzerinden kişiselleştirilmiş NLU (backend proxy)
//   Mod2 : CommandParser — kural tabanlı fallback (internet gerekmez)
//
// ── Yanıt Kaynağı ─────────────────────────────────────────────────────────
//   "groq"     → Groq API yanıtladı (bağlam bilinçli, serbest dil)
//   "fallback" → CommandParser devreye girdi (kural tabanlı, offline)
//
// ── Güven Skoru Stratejisi ────────────────────────────────────────────────
//   • Eşik: kConfidenceThreshold = 0.70
//   • Bu değerin altındaki sonuçlar kabul edilmez → kullanıcıdan tekrar istenir.
//   • speech_to_text [0..1] aralığında güven skoru döner; web tarafında
//     tarayıcı bazen 0.0 döndürür — bu durumda transkript uzunluğu
//     yeterince uzunsa kabul edilir (fallback).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'command_parser.dart';
import 'api_service.dart';

// ── Sabitler ──────────────────────────────────────────────────────────────────

/// Kabul edilebilir minimum güven skoru.
/// Bu eşiğin altındaki sonuçlar geri bildirimle reddedilir.
const double kConfidenceThreshold = 0.70;

/// Tarayıcı 0.0 güven döndürdüğünde kabul için minimum karakter uzunluğu.
const int kMinTranscriptLength = 4;

/// Dinleme zaman aşımı (kullanıcı hiç konuşmazsa)
const Duration kListenTimeout = Duration(seconds: 8);

/// Sessizlik algılama süresi (konuşma bitince otomatik dur)
const Duration kPauseTimeout = Duration(seconds: 2);

// ── Durumlar ──────────────────────────────────────────────────────────────────

enum VoiceState {
  idle,       // Başlangıç / hazır
  listening,  // Mikrofon açık, speech bekleniyor
  processing, // Komut işleniyor
  speaking,   // TTS konuşuyor
  error,      // Hata durumu
}

// ─────────────────────────────────────────────────────────────────────────────

class VoiceController extends ChangeNotifier {
  final ApiService _api;

  VoiceController({required ApiService api}) : _api = api;

  // ── Dahili bileşenler ──────────────────────────────────────────────────────
  final SpeechToText _stt  = SpeechToText();
  final FlutterTts   _tts  = FlutterTts();
  final CommandParser _parser = CommandParser();

  // ── Durum alanları ─────────────────────────────────────────────────────────
  VoiceState _state = VoiceState.idle;
  VoiceState get state => _state;

  /// Son başarıyla ayrıştırılan komut (fallback modunda dolu, Groq'ta null)
  ParsedCommand? _lastCommand;
  ParsedCommand? get lastCommand => _lastCommand;

  /// Yanıtın kaynağı: "groq" | "fallback"
  String _lastAnswerSource = 'fallback';
  String get lastAnswerSource => _lastAnswerSource;

  /// Ekranda görüntülenen geçici transkript (son partials)
  String _liveTranscript = '';
  String get liveTranscript => _liveTranscript;

  /// Son güven skoru (0.0–1.0)
  double _lastConfidence = 0.0;
  double get lastConfidence => _lastConfidence;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// STT başlatma hatası varsa true (izin yok, donanım yok vb.)
  bool _sttUnavailable = false;
  bool get isSttUnavailable => _sttUnavailable;

  /// Callback: komut başarıyla ayrıştırıldığında tetiklenir.
  /// Ekran, bu callback'le navigasyon veya API çağrısı yapabilir.
  /// [source] "groq" veya "fallback" olabilir.
  void Function(ParsedCommand)? onCommandParsed;

  /// Groq'tan doğrudan cevap geldiğinde tetiklenir (TTS için de kullanılır).
  /// [source] == "groq" ise bu callback çağrılır; [onCommandParsed] çağrılmaz.
  void Function(VoiceAIResult result)? onGroqAnswer;

  // ── Başlatma ───────────────────────────────────────────────────────────────

  /// Uygulama başlatıldığında veya ilk kullanımda çağrılmalı.
  Future<void> init() async {
    if (_isInitialized) return;

    // ── TTS Konfigürasyonu ──────────────────────
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.9);   // Doğal konuşma hızı
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Web ortamında daha doğal ses seç (Google TTS varsa)
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        // Google TR sesi önce, sonra herhangi bir tr-TR sesi
        final preferred = (voices as List<dynamic>).cast<Map>().where((v) {
          final name   = (v['name']   as String? ?? '').toLowerCase();
          final locale = (v['locale'] as String? ?? '').toLowerCase();
          return locale.startsWith('tr');
        }).toList();

        Map? bestVoice;
        for (final v in preferred) {
          final name = (v['name'] as String? ?? '').toLowerCase();
          if (name.contains('google')) { bestVoice = v; break; }
        }
        bestVoice ??= preferred.isNotEmpty ? preferred.first : null;

        if (bestVoice != null) {
          await _tts.setVoice({
            'name':   bestVoice['name'] as String,
            'locale': bestVoice['locale'] as String,
          });
        }
      }
    } catch (_) {
      // Ses listesi alınamasa da devam et
    }

    // TTS tamamlandığında state'i güncelle
    _tts.setCompletionHandler(() {
      if (_state == VoiceState.speaking) {
        _setState(VoiceState.idle);
      }
    });

    // ── STT Başlatma ───────────────────────────
    final available = await _stt.initialize(
      onError: _onSttError,
      onStatus: _onSttStatus,
    );

    if (!available) {
      _sttUnavailable = true;
      debugPrint('[Voice] STT başlatılamadı — tarayıcı desteklemiyor olabilir.');
    }

    _isInitialized = true;
    notifyListeners();
  }

  // ── Dinlemeyi Başlat ───────────────────────────────────────────────────────

  /// Mikrofonu açar ve konuşmayı dinlemeye başlar.
  Future<void> startListening() async {
    if (!_isInitialized) await init();
    if (_sttUnavailable) {
      await speak('Mikrofon erişimi sağlanamadı. Lütfen tarayıcı iznini kontrol edin.');
      return;
    }
    if (_state == VoiceState.listening || _state == VoiceState.speaking) return;

    _liveTranscript = '';
    _setState(VoiceState.listening);

    await _stt.listen(
      localeId: 'tr-TR',
      listenFor: kListenTimeout,
      pauseFor: kPauseTimeout,
      onResult: _onSttResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  // ── Dinlemeyi Durdur ───────────────────────────────────────────────────────

  Future<void> stopListening() async {
    if (_state != VoiceState.listening) return;
    await _stt.stop();
    _setState(VoiceState.idle);
  }

  /// Hem dinlemeyi hem TTS'i durdurur (kullanıcı iptal düğmesine bastığında).
  Future<void> cancel() async {
    await _stt.cancel();
    await _tts.stop();
    _liveTranscript = '';
    _setState(VoiceState.idle);
  }

  // ── TTS: Konuşma Üret ─────────────────────────────────────────────────────

  /// [text] metnini Türkçe sentezlenmiş sesle okur.
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _tts.stop(); // önceki konuşmayı kes
    _setState(VoiceState.speaking);
    await _tts.speak(text);
  }

  // ── Bildirim Sesi (Modül 2 entegrasyonu) ─────────────────────────────────

  /// Doz bildirimi geldiğinde çağrılır; ekran kilitli olsa bile
  /// TTS ile hatırlatma sesini sentezler.
  Future<void> announceReminder({
    required String medicationName,
    required String scheduledTime,
  }) async {
    await speak(
      '$medicationName ilacınızı alma zamanı geldi. Planlanan saat: $scheduledTime.',
    );
  }

  // ── STT Sonuç İşleyici ────────────────────────────────────────────────────

  void _onSttResult(SpeechRecognitionResult result) {
    // Kısmi sonuçları anlık göstermek için kaydet
    _liveTranscript = result.recognizedWords;
    notifyListeners();

    // Yalnızca final sonuçları işle
    if (!result.finalResult) return;

    _processTranscript(result.recognizedWords.trim(), result.confidence);
  }

  Future<void> _processTranscript(String text, double confidence) async {
    if (text.isEmpty) {
      _handleLowConfidence('Ses anlaşılamadı. Lütfen tekrar konuşun.');
      return;
    }

    // ── Güven Skoru Kontrolü ───────────────────────────────────────────────
    _lastConfidence = confidence;
    debugPrint('[Voice] Transkript: "$text" | Güven: ${confidence.toStringAsFixed(2)}');

    // Web tarayıcılar zaman zaman 0.0 döner → uzunluk fallback'i
    final bool confidenceAccepted = confidence == 0.0
        ? text.length >= kMinTranscriptLength
        : confidence >= kConfidenceThreshold;

    if (!confidenceAccepted) {
      _handleLowConfidence(
        'Komut yeterince anlaşılamadı. '
        'Biraz daha yüksek sesle veya yakından konuşabilir misiniz?',
      );
      return;
    }

    // ── Intent Ayrıştırma — Groq önce, kural motoru fallback ────────────
    _setState(VoiceState.processing);

    // 1. Groq backend'i dene
    try {
      final aiResult = await _api.voiceQuery(text);
      if (!aiResult.isFallback) {
        _lastAnswerSource = 'groq';
        debugPrint('[Voice] Groq yanıtı: ${aiResult.answer}');
        onGroqAnswer?.call(aiResult);
        if (_state == VoiceState.processing) _setState(VoiceState.idle);
        return;
      }
    } catch (e) {
      debugPrint('[Voice] Groq çağrısı hata: $e');
    }

    // 2. Kural motoru fallback
    _lastAnswerSource = 'fallback';
    final cmd = _parser.parse(text);
    _lastCommand = cmd;
    debugPrint('[Voice] Kural motoru: $cmd');

    onCommandParsed?.call(cmd);

    // İşleme tamamlandı; konuşma state'ye geçiş speak() içinde olur.
    if (_state == VoiceState.processing) _setState(VoiceState.idle);
  }

  // ── STT Durum Değişimi ────────────────────────────────────────────────────

  void _onSttStatus(String status) {
    debugPrint('[Voice] STT Durum: $status');
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      if (_state == VoiceState.listening) {
        // Kullanıcı hiç konuşmadıysa uyar
        if (_liveTranscript.isEmpty) {
          _handleLowConfidence('Ses algılanamadı. Lütfen konuşmayı deneyin.');
        }
      }
    }
  }

  // ── STT Hata İşleyici ─────────────────────────────────────────────────────

  void _onSttError(SpeechRecognitionError error) {
    debugPrint('[Voice] STT Hata: ${error.errorMsg} (kalıcı: ${error.permanent})');

    if (error.permanent) {
      _sttUnavailable = true;
    }
    _setState(VoiceState.error);
    speak('Ses tanıma hatası oluştu. Lütfen tekrar deneyin.').ignore();
  }

  // ── Düşük Güven Skoru ─────────────────────────────────────────────────────

  void _handleLowConfidence(String message) {
    _setState(VoiceState.idle);
    speak(message).ignore();
  }

  // ── Dahili State Yönetimi ─────────────────────────────────────────────────

  void _setState(VoiceState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  // ── Kaynak Temizliği ──────────────────────────────────────────────────────

  @override
  void dispose() {
    _stt.stop();
    _tts.stop();
    super.dispose();
  }
}
