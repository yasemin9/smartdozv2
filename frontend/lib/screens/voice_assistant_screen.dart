// SmartDoz - Sesli Asistan Ekranı v2 (Modül 6)
//
// ── Mimari (AI-First) ────────────────────────────────────────────────────────
//
//   Her sorgu (sesli veya yazılı) şu hiyerarşiyi izler:
//   1. POST /ai/voice-query  → Groq Llama 3.1 (bağlam bilinçli, serbest dil)
//   2. Groq başarısız        → CommandParser sadece navigationlar için
//      (addMedication → ilgili ekrana yönlendir)
//   3. Her iki yol da başarısız → offline bildirisi + hızlı erişim kısayolları
//
// ── Kullanıcı Girişi ─────────────────────────────────────────────────────────
//   • Mikrofon düğmesi  — konuşarak sorgu
//   • TextField         — yazarak sorgu (erişilebilirlik / ses çalışmıyorsa)
//
// ── Erişilebilirlik ──────────────────────────────────────────────────────────
//   • Tüm bileşenler Semantics etiketli (WCAG AA)
//   • liveRegion: sohbet güncellemeleri ekran okuyucuya iletilir
//   • Minimum 48 × 48 dp dokunma hedefi
//   • Renk + metin + ikon: renk tek gösterge değil

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/voice_controller.dart';
import '../services/command_parser.dart';
import '../services/api_service.dart';
import '../models/medication.dart';
import 'add_medication_screen.dart';

// ── Renk Paleti ───────────────────────────────────────────────────────────────
const _kBg        = Color(0xFFF0F4FF);
const _kPrimary   = Color(0xFF1565C0);
const _kSuccess   = Color(0xFF2E7D32);
const _kTextDark  = Color(0xFF0D1B2A);
const _kTextMid   = Color(0xFF455A64);
const _kGroqColor = Color(0xFF6A1B9A);   // mor — Groq AI yanıtı
const _kOffline   = Color(0xFF78909C);   // gri — offline bildirisi

// ── Mesaj Modeli ──────────────────────────────────────────────────────────────

enum _MsgSource { user, ai, thinking, offline }

class _Msg {
  final _MsgSource source;
  final String text;
  _Msg(this.source, this.text);
}

// ── Sesli Form Sihirbazı ──────────────────────────────────────────────────────

enum _WizardStep {
  none,            // sihirbaz kapalı
  searchResults,   // ilaç seçimi bekleniyor
  dosageForm,      // "Tablet mi, şurup mu?"
  frequency,       // "Günde kaç kez?"
  usageTime,       // "Ne zaman alıyorsunuz?"
  expiryDate,      // "Son kullanma tarihi?"
  confirm,         // özet onayı
}

// Sabit listeler (add_medication_screen ile aynı)
const _kDosageForms = [
  'Tablet', 'Şurup', 'Kapsül', 'Enjeksiyon',
  'Damla', 'Krem / Merhem', 'Toz', 'Diğer',
];
const _kFrequencies = [
  'Günde 1 kez', 'Günde 2 kez', 'Günde 3 kez',
  'Her 8 saatte bir', 'Her 12 saatte bir',
  'Haftada 1 kez', 'Gerektiğinde',
];
const _kUsageTimes = [
  'Sabah', 'Öğle', 'Akşam', 'Yatmadan önce',
  'Yemekten önce', 'Yemekten sonra', 'Aç karnına',
];

// Türkçe ay adları → ay numarası
const _kMonths = {
  'ocak': 1, 'şubat': 2, 'mart': 3, 'nisan': 4, 'mayıs': 5, 'haziran': 6,
  'temmuz': 7, 'ağustos': 8, 'eylül': 9, 'ekim': 10, 'kasım': 11, 'aralık': 12,
};

// ─────────────────────────────────────────────────────────────────────────────

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final VoiceController _ctrl;
  final _parser   = CommandParser();

  final _scroll   = ScrollController();
  final _textCtrl = TextEditingController();
  final _textFocus = FocusNode();
  final List<_Msg> _msgs = [];

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // ── Onay Bekliyor Durumu ──────────────────────────────────────────────────
  String? _pendingAction;         // "delete_medication" | "log_dose"
  int?    _pendingMedicationId;
  String? _pendingMedicationName;
  int?    _pendingDoseLogId;

  static final _rYes = RegExp(r'\b(evet|tamam|onayla|onay|ok|sil|evet sil|kabul)\b', caseSensitive: false, unicode: true);
  static final _rNo  = RegExp(r'\b(hayır|hayir|iptal|vazgeç|vazgec|dur|istemiyorum)\b', caseSensitive: false, unicode: true);

  // ── İlaç Ekleme Sihirbazı ─────────────────────────────────────────────────
  _WizardStep _wizardStep = _WizardStep.none;
  List<MedSearchResult> _wizardCandidates = [];
  MedSearchResult? _wizardSelectedMed;
  String? _wizardDosageForm;
  String? _wizardFrequency;
  String? _wizardUsageTime;
  DateTime? _wizardExpiry;

  bool get _wizardActive => _wizardStep != _WizardStep.none;

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _ctrl = VoiceController(api: context.read<ApiService>());

    // Groq yanıtı (sesli yol) → AI balonuna ekle + TTS + action işle
    _ctrl.onGroqAnswer = (result) {
      final spoken = _ctrl.liveTranscript.trim();
      if (spoken.isNotEmpty) _push(_Msg(_MsgSource.user, spoken));
      _removeThinking();
      _push(_Msg(_MsgSource.ai, result.answer!));
      _ctrl.speak(result.answer!).ignore();

      // Action varsa onay bekleme moduna geç
      if (result.action != null) {
        setState(() {
          _pendingAction         = result.action;
          _pendingMedicationId   = result.medicationId;
          _pendingMedicationName = result.medicationName;
          _pendingDoseLogId      = result.doseLogId;
        });
      }
    };

    // Fallback sesli yol: sadece navigation intent için
    _ctrl.onCommandParsed = (cmd) {
      _removeThinking();
      if (cmd.intent == VoiceIntent.addMedication) {
        _wizardStart(cmd.medicationName);
      }
    };

    // Nabız animasyonu
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.20).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _ctrl.addListener(_onCtrl);

    // Karşılama
    _push(_Msg(_MsgSource.ai,
      'Merhaba! İlaçlarınızla ilgili her türlü soruyu sorabilirsiniz. '
      'Mikrofona basın veya aşağıdan yazın.'));
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_onCtrl)
      ..dispose();
    _pulseCtrl.dispose();
    _scroll.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _onCtrl() => setState(() {});

  // ── Mesaj Yönetimi ────────────────────────────────────────────────────────

  void _push(_Msg msg) {
    setState(() => _msgs.add(msg));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addThinking() => _push(_Msg(_MsgSource.thinking, ''));

  void _removeThinking() {
    setState(() => _msgs.removeWhere((m) => m.source == _MsgSource.thinking));
  }

  // ── Ana Sorgu Gönderme (metin veya sesli transcript) ─────────────────────

  Future<void> _sendQuery(String text) async {
    if (text.trim().isEmpty) return;
    _textCtrl.clear();
    _textFocus.unfocus();

    _push(_Msg(_MsgSource.user, text));

    // ── Sihirbaz aktifse ona yönlendir ───────────────────────────────────
    if (_wizardActive) {
      await _wizardHandleInput(text);
      return;
    }

    // ── Bekleyen Onay Varsa Cevabı İşle ─────────────────────────────────
    if (_pendingAction != null) {
      await _handleConfirmationReply(text);
      return;
    }

    _addThinking();

    final api = context.read<ApiService>();
    try {
      final result = await api.voiceQuery(text);
      _removeThinking();

      if (!result.isFallback) {
        _push(_Msg(_MsgSource.ai, result.answer!));
        await _ctrl.speak(result.answer!);

        // add_medication → sihirbazı başlat, delete → onay bekle, log_dose → onay bekle
        if (result.action == 'add_medication') {
          await _wizardStart(result.medicationName);
        } else if (result.action == 'delete_medication' || result.action == 'log_dose') {
          setState(() {
            _pendingAction         = result.action;
            _pendingMedicationId   = result.medicationId;
            _pendingMedicationName = result.medicationName;
            _pendingDoseLogId      = result.doseLogId;
          });
        }
      } else {
        final cmd = _parser.parse(text);
        if (cmd.intent == VoiceIntent.addMedication) {
          await _wizardStart(cmd.medicationName);
        } else {
          _push(_Msg(_MsgSource.offline,
            'Yapay zeka şu an yanıt veremiyor. '
            'Backend sunucusunun çalıştığından emin olun.'));
        }
      }
    } catch (_) {
      _removeThinking();
      _push(_Msg(_MsgSource.offline,
        'Bağlantı hatası. İnternet bağlantınızı kontrol edin.'));
    }
  }

  // ── Onay Yanıtını İşle (sil) ─────────────────────────────────────────────

  Future<void> _handleConfirmationReply(String text) async {
    final norm = text.toLowerCase().trim();

    if (_rYes.hasMatch(norm)) {
      if (_pendingAction == 'delete_medication') {
        await _executDelete();
      } else if (_pendingAction == 'log_dose') {
        await _executeLogDose();
      }
    } else if (_rNo.hasMatch(norm)) {
      final msg = 'Tamam, işlem iptal edildi.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    } else {
      final med = _pendingMedicationName ?? 'ilacı';
      final msg = '"$med" için işlemi onaylamak isterseniz "Evet", iptal etmek için "Hayır" deyin.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }

    setState(() {
      _pendingAction = null;
      _pendingMedicationId = null;
      _pendingMedicationName = null;
      _pendingDoseLogId = null;
    });
  }

  // ── Doz Alındı İşlemi ────────────────────────────────────────────────────

  Future<void> _executeLogDose() async {
    final api = context.read<ApiService>();
    final medName = _pendingMedicationName ?? 'İlaç';
    if (_pendingDoseLogId == null) {
      final msg = 'Bugün $medName için bekleyen bir doz bulamadım.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }
    try {
      await api.updateDoseStatus(_pendingDoseLogId!, 'Alındı');
      final msg = '$medName bugün alındı olarak işaretlendi.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    } catch (_) {
      final msg = '$medName dozu işaretlenirken bir hata oluştu.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    }
  }

  // ── Silme İşlemi ──────────────────────────────────────────────────────────

  Future<void> _executDelete() async {
    final api = context.read<ApiService>();
    final medName = _pendingMedicationName ?? 'İlaç';
    if (_pendingMedicationId == null) {
      final msg = 'Silmek istediğiniz ilacı bulamadım. İlaç adını daha açık belirtin.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }
    try {
      await api.deleteMedication(_pendingMedicationId!);
      final msg = '$medName başarıyla ilaç listenizden kaldırıldı.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    } catch (_) {
      final msg = '$medName silinirken bir hata oluştu.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // İLAÇ EKLEME SİHİRBAZI
  // ════════════════════════════════════════════════════════════════════════════

  void _wizardReset() {
    setState(() {
      _wizardStep         = _WizardStep.none;
      _wizardCandidates   = [];
      _wizardSelectedMed  = null;
      _wizardDosageForm   = null;
      _wizardFrequency    = null;
      _wizardUsageTime    = null;
      _wizardExpiry       = null;
    });
  }

  Future<void> _wizardStart(String? medName) async {
    _wizardReset();
    if (medName == null || medName.isEmpty) {
      final msg = 'Eklemek istediğiniz ilacın adını söyleyin.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      setState(() => _wizardStep = _WizardStep.searchResults);
      return;
    }
    await _wizardSearch(medName);
  }

  Future<void> _wizardSearch(String query) async {
    _addThinking();
    final api = context.read<ApiService>();
    final results = await api.voiceMedSearch(query);
    _removeThinking();

    if (results.isEmpty) {
      final msg = '"$query" için ilaç bulunamadı. Farklı bir isimle tekrar deneyin.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      setState(() => _wizardStep = _WizardStep.searchResults);
      return;
    }

    setState(() {
      _wizardCandidates = results;
      _wizardStep       = _WizardStep.searchResults;
    });

    // Sözlü listeyi oku
    final sb = StringBuffer('Şu ilaçları buldum: ');
    for (var i = 0; i < results.length; i++) {
      sb.write('${i + 1}. ${results[i].productName}. ');
    }
    sb.write('Hangisini eklemek istiyorsunuz? Numarasını söyleyin.');
    final msg = sb.toString();
    _push(_Msg(_MsgSource.ai, msg));
    await _ctrl.speak(msg);
  }

  Future<void> _wizardHandleInput(String text) async {
    final norm = text.toLowerCase().trim();

    // İptal kontrolü her adımda
    if (_rNo.hasMatch(norm) || norm.contains('iptal') || norm.contains('vazgeç')) {
      _wizardReset();
      const msg = 'İlaç ekleme işlemi iptal edildi.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }

    switch (_wizardStep) {
      case _WizardStep.searchResults:
        await _wizardHandleSelection(norm);
      case _WizardStep.dosageForm:
        await _wizardHandleDosageForm(norm);
      case _WizardStep.frequency:
        await _wizardHandleFrequency(norm);
      case _WizardStep.usageTime:
        await _wizardHandleUsageTime(norm);
      case _WizardStep.expiryDate:
        await _wizardHandleExpiry(norm);
      case _WizardStep.confirm:
        await _wizardHandleConfirm(norm);
      default:
        break;
    }
  }

  Future<void> _wizardHandleSelection(String norm) async {
    // Numara ile seçim (birinci/1, ikinci/2 ...)
    final num = _parseOrdinal(norm);
    MedSearchResult? picked;

    if (num != null && num >= 1 && num <= _wizardCandidates.length) {
      picked = _wizardCandidates[num - 1];
    } else {
      // İsimle fuzzy eşleştir
      for (final c in _wizardCandidates) {
        if (c.productName.toLowerCase().contains(norm) ||
            norm.contains(c.productName.toLowerCase().split(' ').first)) {
          picked = c;
          break;
        }
      }
    }

    if (picked == null) {
      // Yeni arama mı yapıyorlar?
      if (norm.length >= 3) {
        await _wizardSearch(norm);
        return;
      }
      const msg = 'Anlayamadım. Lütfen sıra numarasını veya ilaç adını söyleyin.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }

    setState(() {
      _wizardSelectedMed = picked;
      _wizardStep        = _WizardStep.dosageForm;
    });

    final optStr = _kDosageForms.join(', ');
    final msg = '${picked.productName} seçildi. Dozaj formu nedir? $optStr';
    _push(_Msg(_MsgSource.ai, msg));
    await _ctrl.speak(msg);
  }

  Future<void> _wizardHandleDosageForm(String norm) async {
    final match = _matchFromList(_kDosageForms, norm);
    if (match == null) {
      final msg = 'Anlayamadım. Şunlardan birini söyleyin: ${_kDosageForms.join(', ')}';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }
    setState(() {
      _wizardDosageForm = match;
      _wizardStep       = _WizardStep.frequency;
    });
    final msg = '$match seçildi. Kullanım sıklığı? ${_kFrequencies.join(', ')}';
    _push(_Msg(_MsgSource.ai, msg));
    await _ctrl.speak(msg);
  }

  Future<void> _wizardHandleFrequency(String norm) async {
    final match = _matchFromList(_kFrequencies, norm);
    if (match == null) {
      final msg = 'Anlayamadım. Şunlardan birini söyleyin: ${_kFrequencies.join(', ')}';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }
    setState(() {
      _wizardFrequency = match;
      _wizardStep      = _WizardStep.usageTime;
    });
    final msg = '$match. Peki ne zaman alıyorsunuz? ${_kUsageTimes.join(', ')}';
    _push(_Msg(_MsgSource.ai, msg));
    await _ctrl.speak(msg);
  }

  Future<void> _wizardHandleUsageTime(String norm) async {
    final match = _matchFromList(_kUsageTimes, norm);
    if (match == null) {
      final msg = 'Anlayamadım. Şunlardan birini söyleyin: ${_kUsageTimes.join(', ')}';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }
    setState(() {
      _wizardUsageTime = match;
      _wizardStep      = _WizardStep.expiryDate;
    });
    const msg = 'Tamam. Son kullanma tarihi? Ay ve yıl olarak söyleyin. Örnek: Aralık 2027';
    _push(_Msg(_MsgSource.ai, msg));
    await _ctrl.speak(msg);
  }

  Future<void> _wizardHandleExpiry(String norm) async {
    final dt = _parseMonthYear(norm);
    if (dt == null) {
      const msg = 'Tarihi anlayamadım. Örnek: "Mart 2028" şeklinde söyleyin.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
      return;
    }
    setState(() {
      _wizardExpiry = dt;
      _wizardStep   = _WizardStep.confirm;
    });
    final med   = _wizardSelectedMed!.productName;
    final expStr = '${dt.month}/${dt.year}';
    final msg = 'Özet: $med, $_wizardDosageForm, $_wizardFrequency, '
                '$_wizardUsageTime, son kullanma $expStr. Ekleyeyim mi?';
    _push(_Msg(_MsgSource.ai, msg));
    await _ctrl.speak(msg);
  }

  Future<void> _wizardHandleConfirm(String norm) async {
    if (_rYes.hasMatch(norm)) {
      await _wizardSubmit();
    } else if (_rNo.hasMatch(norm)) {
      _wizardReset();
      const msg = 'İlaç ekleme iptal edildi.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    } else {
      const msg = 'Eklememi istiyorsanız "Evet", iptal için "Hayır" deyin.';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    }
  }

  Future<void> _wizardSubmit() async {
    final api = context.read<ApiService>();
    final selectedMed = _wizardSelectedMed!;
    final medication = Medication(
      name:            selectedMed.productName,
      dosageForm:      _wizardDosageForm!,
      usageFrequency:  _wizardFrequency!,
      usageTime:       _wizardUsageTime!,
      expiryDate:      _wizardExpiry!,
      activeIngredient: selectedMed.activeIngredient,
      atcCode:         selectedMed.atcCode,
      barcode:         selectedMed.barcode,
    );

    _addThinking();
    try {
      await api.createMedication(medication);
      _removeThinking();
      final msg = '${selectedMed.productName} başarıyla ilaç listenize eklendi!';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    } catch (e) {
      _removeThinking();
      final msg = 'İlaç eklenemedi: ${e.toString().replaceAll('ApiException: ', '')}';
      _push(_Msg(_MsgSource.ai, msg));
      await _ctrl.speak(msg);
    } finally {
      _wizardReset();
    }
  }

  // ── Yardımcı Çözümleyiciler ───────────────────────────────────────────────

  /// Sıralı sayı (birinci/1/bir) → 1-tabanlı int
  int? _parseOrdinal(String norm) {
    const ordinals = {
      'birinci': 1, 'bir': 1, '1': 1,
      'ikinci': 2, 'iki': 2, '2': 2,
      'üçüncü': 3, 'üç': 3, '3': 3,
      'dördüncü': 4, 'dört': 4, '4': 4,
      'beşinci': 5, 'beş': 5, '5': 5,
    };
    for (final entry in ordinals.entries) {
      if (norm.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Listeden en iyi eşleşme (kelime içeriyor mu kontrolü)
  String? _matchFromList(List<String> options, String norm) {
    // Tam eşleşme önce
    for (final opt in options) {
      if (norm == opt.toLowerCase()) return opt;
    }
    // İçerik eşleşmesi
    for (final opt in options) {
      final optNorm = opt.toLowerCase();
      final words   = optNorm.split(RegExp(r'\s+'));
      if (words.any((w) => norm.contains(w) && w.length >= 3)) return opt;
    }
    return null;
  }

  /// "Aralık 2027" → DateTime(2027, 12, 31)
  DateTime? _parseMonthYear(String norm) {
    int? month;
    int? year;

    for (final entry in _kMonths.entries) {
      if (norm.contains(entry.key)) { month = entry.value; break; }
    }
    final yearMatch = RegExp(r'(20\d{2})').firstMatch(norm);
    if (yearMatch != null) year = int.tryParse(yearMatch.group(1)!);

    if (month == null || year == null) return null;
    // Ayın son gününü al
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, lastDay);
  }

  // ── Mikrofon Butonu ───────────────────────────────────────────────────────

  Future<void> _onMicPressed() async {
    if (!_ctrl.isInitialized) await _ctrl.init();

    switch (_ctrl.state) {
      case VoiceState.listening:
        await _ctrl.stopListening();
      case VoiceState.speaking:
        await _ctrl.cancel();
      default:
        _addThinking();
        await _ctrl.startListening();
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isListening  = _ctrl.state == VoiceState.listening;
    final isProcessing = _ctrl.state == VoiceState.processing;
    final isSpeaking   = _ctrl.state == VoiceState.speaking;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(isListening, isProcessing),
      body: SafeArea(
        child: Column(
          children: [
            // ── Sohbet Listesi ────────────────────────────────────────────
            Expanded(
              child: Semantics(
                label: 'Sohbet geçmişi',
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: _msgs.length,
                  itemBuilder: (ctx, i) => _MsgBubble(key: ValueKey(i), msg: _msgs[i]),
                ),
              ),
            ),

            // ── Canlı Transkript ──────────────────────────────────────────
            if (isListening && _ctrl.liveTranscript.isNotEmpty)
              Semantics(
                liveRegion: true,
                label: 'Tanınan metin: ${_ctrl.liveTranscript}',
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _kPrimary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hearing, size: 16, color: _kPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _ctrl.liveTranscript,
                          style: const TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: _kTextMid),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

      // ── Sihirbaz Adım Göstergesi ─────────────────────────────────────
            if (_wizardActive) _WizardStepBar(step: _wizardStep),

            // ── Sihirbaz: İlaç Aday Kartları ─────────────────────────────
            if (_wizardStep == _WizardStep.searchResults &&
                _wizardCandidates.isNotEmpty)
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: _wizardCandidates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final med = _wizardCandidates[i];
                    return _MedCandidateCard(
                      index: i + 1,
                      med: med,
                      onTap: () => _sendQuery('${i + 1}'),
                    );
                  },
                ),
              ),

            // ── Sihirbaz: Seçenek Çipleri (dosage/freq/time/confirm) ─────
            if (_wizardStep == _WizardStep.dosageForm)
              _OptionChips(options: _kDosageForms, onSelect: _sendQuery),
            if (_wizardStep == _WizardStep.frequency)
              _OptionChips(options: _kFrequencies, onSelect: _sendQuery),
            if (_wizardStep == _WizardStep.usageTime)
              _OptionChips(options: _kUsageTimes, onSelect: _sendQuery),
            if (_wizardStep == _WizardStep.confirm ||
                _pendingAction != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kSuccess,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Evet, onayla'),
                        onPressed: () => _sendQuery('evet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Hayır, iptal'),
                        onPressed: () => _sendQuery('hayır'),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Giriş Çubuğu ─────────────────────────────────────────────
            _buildInputBar(isListening, isProcessing, isSpeaking),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  AppBar _buildAppBar(bool isListening, bool isProcessing) {
    final source = _ctrl.lastAnswerSource;
    return AppBar(
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: const Row(
        children: [
          SizedBox(width: 4),
          Icon(Icons.smart_toy_outlined, size: 22),
          SizedBox(width: 8),
          Text('Sesli Asistan',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
      actions: [
        Semantics(
          label: 'Yanıt kaynağı',
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isListening || isProcessing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white70),
                    ),
                  const SizedBox(width: 6),
                  _SourceBadge(source: source),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar(bool isListening, bool isProcessing, bool isSpeaking) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          // ── Metin Girişi ─────────────────────────────────────────────
          Expanded(
            child: Semantics(
              label: 'Mesaj yaz',
              textField: true,
              child: TextField(
                controller: _textCtrl,
                focusNode: _textFocus,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15, color: _kTextDark),
                decoration: InputDecoration(
                  hintText: 'Bir şey sorun…',
                  hintStyle: const TextStyle(color: _kTextMid),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: _kBg,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                onSubmitted: _sendQuery,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Gönder veya Mikrofon ──────────────────────────────────────
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textCtrl,
            builder: (_, val, __) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: val.text.isNotEmpty
                  ? Semantics(
                      label: 'Mesajı gönder',
                      button: true,
                      child: _CircleBtn(
                        key: const ValueKey('send'),
                        color: _kPrimary,
                        icon: Icons.send_rounded,
                        onTap: () => _sendQuery(_textCtrl.text),
                      ),
                    )
                  : _MicButton(
                      key: const ValueKey('mic'),
                      isListening: isListening,
                      isSpeaking: isSpeaking,
                      isProcessing: isProcessing,
                      pulseAnim: _pulseAnim,
                      onTap: _onMicPressed,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Kaynak badge
// ─────────────────────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isAI = source == 'groq';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isAI ? _kGroqColor : Colors.white24,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAI ? Icons.auto_awesome : Icons.wifi_off,
              size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            isAI ? 'Groq AI' : 'Çevrimdışı',
            style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yuvarlak buton
// ─────────────────────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _CircleBtn(
      {super.key,
      required this.color,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mikrofon butonu (nabız animasyonlu)
// ─────────────────────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final bool isListening, isSpeaking, isProcessing;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;
  const _MicButton({
    super.key,
    required this.isListening,
    required this.isSpeaking,
    required this.isProcessing,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final IconData ic;
    if (isListening) {
      bg = Colors.red.shade600;
      ic = Icons.stop_rounded;
    } else if (isSpeaking) {
      bg = _kSuccess;
      ic = Icons.volume_up_rounded;
    } else if (isProcessing) {
      bg = _kTextMid;
      ic = Icons.hourglass_top_rounded;
    } else {
      bg = _kPrimary;
      ic = Icons.mic_rounded;
    }

    return Semantics(
      label: isListening ? 'Dinlemeyi durdur' : 'Sesli konuş',
      button: true,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: isListening ? pulseAnim.value : 1.0,
          child: child,
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: bg.withAlpha(80),
                    blurRadius: 12,
                    spreadRadius: 2)
              ],
            ),
            child: Icon(ic, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mesaj kabarcığı
// ─────────────────────────────────────────────────────────────────────────────

class _MsgBubble extends StatelessWidget {
  final _Msg msg;
  const _MsgBubble({super.key, required this.msg});

  @override
  Widget build(BuildContext context) {
    if (msg.source == _MsgSource.thinking) return _ThinkingBubble();

    final isUser    = msg.source == _MsgSource.user;
    final isAI      = msg.source == _MsgSource.ai;
    final isOffline = msg.source == _MsgSource.offline;

    final Color bg;
    final Color fg;
    if (isUser) {
      bg = _kPrimary;
      fg = Colors.white;
    } else if (isAI) {
      bg = _kGroqColor;
      fg = Colors.white;
    } else if (isOffline) {
      bg = _kOffline.withAlpha(30);
      fg = _kOffline;
    } else {
      bg = Colors.white;
      fg = _kTextDark;
    }

    final labelPrefix = isUser
        ? 'Siz'
        : isAI
            ? 'Yapay Zeka'
            : isOffline
                ? 'Çevrimdışı'
                : 'Asistan';

    return Semantics(
      label: '$labelPrefix: ${msg.text}',
      liveRegion: !isUser,
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (isAI || isOffline)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAI ? Icons.auto_awesome : Icons.wifi_off,
                      size: 12,
                      color: isAI ? _kGroqColor : _kOffline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAI ? 'Groq AI' : 'Çevrimdışı',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isAI ? _kGroqColor : _kOffline,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isOffline
                    ? Border.all(color: _kOffline.withAlpha(80))
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                    fontSize: 15, color: fg, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// "Düşünüyor…" animasyonlu placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ThinkingBubble extends StatefulWidget {
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _dot = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _t = Timer.periodic(const Duration(milliseconds: 450),
        (_) => setState(() => _dot = (_dot + 1) % 4));
  }

  @override
  void dispose() {
    _c.dispose();
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dot;
    return Semantics(
      liveRegion: true,
      label: 'Yapay zeka düşünüyor',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(18),
              topRight:    Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft:  Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation(_kGroqColor),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Düşünüyor$dots',
                style: const TextStyle(
                    fontSize: 14,
                    color: _kTextMid,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sihirbaz: adım ilerleme çubuğu
// ─────────────────────────────────────────────────────────────────────────────

class _WizardStepBar extends StatelessWidget {
  final _WizardStep step;
  const _WizardStepBar({required this.step});

  @override
  Widget build(BuildContext context) {
    const steps = [
      _WizardStep.searchResults,
      _WizardStep.dosageForm,
      _WizardStep.frequency,
      _WizardStep.usageTime,
      _WizardStep.expiryDate,
      _WizardStep.confirm,
    ];
    const labels = ['İlaç', 'Form', 'Sıklık', 'Zaman', 'Tarih', 'Onay'];
    final current = steps.indexOf(step);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 6,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.add_circle_outline, size: 15, color: _kPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(steps.length, (i) {
                final isDone    = i < current;
                final isActive  = i == current;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone
                            ? _kSuccess
                            : isActive
                                ? _kPrimary
                                : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.white : Colors.grey,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 9,
                        color: isActive ? _kPrimary : Colors.grey,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sihirbaz: ilaç aday kartı
// ─────────────────────────────────────────────────────────────────────────────

class _MedCandidateCard extends StatelessWidget {
  final int index;
  final MedSearchResult med;
  final VoidCallback onTap;
  const _MedCandidateCard({
    required this.index,
    required this.med,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kPrimary.withAlpha(60)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: _kPrimary, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    med.productName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _kTextDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (med.activeIngredient != null) ...[
              const SizedBox(height: 4),
              Text(
                med.activeIngredient!,
                style: const TextStyle(fontSize: 10, color: _kTextMid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sihirbaz: seçenek çipleri (dosage / frequency / time)
// ─────────────────────────────────────────────────────────────────────────────

class _OptionChips extends StatelessWidget {
  final List<String> options;
  final void Function(String) onSelect;
  const _OptionChips({required this.options, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(options[i],
              style: const TextStyle(fontSize: 12, color: _kPrimary)),
          backgroundColor: Colors.white,
          side: const BorderSide(color: _kPrimary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: () => onSelect(options[i]),
        ),
      ),
    );
  }
}
