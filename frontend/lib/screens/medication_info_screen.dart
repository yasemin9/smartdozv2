/// SmartDoz - Modül 5: İlaç Bilgi Kartı Ekranı
///
/// Yapay zeka tarafından özetlenen prospektüs bilgilerini
/// kullanıcı dostu kart yapısında sunar.
///
/// Rapor 4.3.5 gereksinimleri:
///   - Endikasyon, Yan Etkiler, Dozaj, Uyarılar bölümleri
///   - NER ile tespit edilen kritik yan etkiler vurgulanır
///   - AI sorumluluk reddi her zaman gösterilir
///   - Kart-tabanlı, okunabilir tipografi ile
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../models/medication_summary.dart';
import '../services/api_service.dart';
import 'prospectus_view_page.dart'; 

// ─────────────────────────────────────────────────────────────────────────────
// Ekrana giriş noktası: medication_id (kullanıcı ilacı) veya globalMedId
// ─────────────────────────────────────────────────────────────────────────────

class MedicationInfoScreen extends StatefulWidget {
  /// Kullanıcının ilaç ID'si (medications tablosu). Öncelikli.
  final int? medicationId;

  /// Global katalog ID'si (global_medications tablosu). medicationId yoksa.
  final int? globalMedId;

  /// Önceden bilinen ilaç adı (yüklenirken gösterilir).
  final String? medicationName;

  const MedicationInfoScreen({
    super.key,
    this.medicationId,
    this.globalMedId,
    this.medicationName,
  }) : assert(
          medicationId != null || globalMedId != null,
          'En az biri belirtilmelidir: medicationId veya globalMedId',
        );

  /// İlacı tam ekran açmak yerine alt sheet olarak gösterir.
  static Future<void> showSheet(
    BuildContext context, {
    int? medicationId,
    int? globalMedId,
    String? medicationName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedSummarySheet(
        medicationId: medicationId,
        globalMedId: globalMedId,
        medicationName: medicationName,
      ),
    );
  }

  @override
  State<MedicationInfoScreen> createState() => _MedicationInfoScreenState();
}

class _MedicationInfoScreenState extends State<MedicationInfoScreen> {
  late Future<MedicationSummary> _summaryFuture;
  late final _TtsController _tts;

  @override
  void initState() {
    super.initState();
    _tts = _TtsController();
    _tts.init();
    _summaryFuture = _fetchSummary();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<MedicationSummary> _fetchSummary() {
    final api = context.read<ApiService>();
    if (widget.medicationId != null) {
      return api.summarizeMedication(widget.medicationId!);
    }
    return api.summarizeGlobalMedication(widget.globalMedId!);
  }

  void _reload() => setState(() => _summaryFuture = _fetchSummary());

  @override
  Widget build(BuildContext context) {
    final titleName = widget.medicationName ?? 'İlaç Bilgisi';
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          titleName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(child: _SpeedButton(tts: _tts)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<MedicationSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }
          if (snapshot.hasError) {
            return _ErrorView(
              error: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Veri bulunamadı.'));
          }
          return _SummaryBody(summary: snapshot.data!, tts: _tts);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prospektüs Eksik Fallback Sabiti
// Backend'den gelen bu metin tespit edildiğinde özel bir bilgilendirme
// bloğu gösterilir; normal madde işareti yerine info-banner kullanılır.
// ─────────────────────────────────────────────────────────────────────────────
const String _kProspectusUnavailable =
    'Bu ilaca ait detaylı prospektüs bilgisi şu an sistemimizde güncellenmektedir. '
    'En doğru bilgi için lütfen doktorunuza veya eczacınıza danışınız.';

// ─────────────────────────────────────────────────────────────────────────────
// TTS Kontrolcüsü — FlutterTts sarmalayıcısı, kart bazlı çalma/durma
// ─────────────────────────────────────────────────────────────────────────────

/// flutter_tts için hız eşleme tablosu.
/// FlutterTts'te 0.5 = normal konuşma hızı (1×).
/// Kullanıcıya gösterilen 1×–2× değerleri buna oranlanır.
const List<double> _kTtsRates   = [0.50, 0.625, 0.75, 0.875, 1.0];
const List<String> _kTtsLabels  = ['1×', '1.25×', '1.5×', '1.75×', '2×'];

class _TtsController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  String? _activeCardId;
  String? _lastText; // hız değişince yeniden başlatmak için saklanır
  bool _speaking = false;
  bool _disposed = false; // async callback'lerin dispose sonrası patlamasını önler
  int _speedIndex = 0;

  bool isSpeaking(String cardId) => _speaking && _activeCardId == cardId;
  bool get anyActive => _speaking;

  int    get speedIndex => _speedIndex;
  String get speedLabel => _kTtsLabels[_speedIndex];
  double get _rate      => _kTtsRates[_speedIndex];

  Future<void> init() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setCompletionHandler(_onDone);
    _tts.setCancelHandler(_onDone);
    // Web'deki SpeechSynthesisErrorEvent'leri sessizce yakala,
    // dispose sonrası notifyListeners çağrısını engelle.
    _tts.setErrorHandler((_) => _onDone());
  }

  /// Hız indeksini günceller.
  /// Okuma devam ediyorsa durdurur ve yeni hızla yeniden başlatır.
  Future<void> setSpeedIndex(int index) async {
    if (_disposed || index == _speedIndex) return;
    _speedIndex = index;
    await _tts.setSpeechRate(_rate);
    if (_disposed) return;

    // Web'de setSpeechRate devam eden konuşmaya uygulanmaz;
    // yeniden başlatmak gerekir.
    if (_speaking && _lastText != null) {
      await _tts.stop();
      if (_disposed) return;
      await _tts.speak(_lastText!);
      if (_disposed) return;
    }
    notifyListeners();
  }

  void _onDone() {
    if (_disposed) return; // dispose sonrası callback → yoksay
    _speaking = false;
    _activeCardId = null;
    _lastText = null;
    notifyListeners();
  }

  /// Kartı sesle oku ya da zaten okunuyorsa durdur.
  Future<void> toggle(String cardId, String text) async {
    if (_disposed) return;

    if (_speaking && _activeCardId == cardId) {
      // Aynı kart → durdur
      await _tts.stop();
      if (_disposed) return;
      _speaking = false;
      _activeCardId = null;
      _lastText = null;
      notifyListeners();
      return;
    }

    if (_speaking) {
      await _tts.stop();
      if (_disposed) return;
    }

    _activeCardId = cardId;
    _lastText = text;
    _speaking = true;
    notifyListeners();
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _disposed = true;
    _tts.stop();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hız Seçici Buton — popup menu ile 1× / 1.25× / 1.5× / 1.75× / 2×
// ─────────────────────────────────────────────────────────────────────────────

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.tts});
  final _TtsController tts;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tts,
      builder: (ctx, _) {
        return PopupMenuButton<int>(
          tooltip: 'Konuşma Hızı',
          offset: const Offset(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: tts.setSpeedIndex,
          itemBuilder: (_) => List.generate(
            _kTtsLabels.length,
            (i) => PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  Icon(
                    tts.speedIndex == i
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: const Color(0xFF1A237E),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _kTtsLabels[i],
                    style: TextStyle(
                      fontWeight: tts.speedIndex == i
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: const Color(0xFF1A237E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed_rounded,
                    size: 16, color: Color(0xFF1A237E)),
                const SizedBox(width: 4),
                Text(
                  tts.speedLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Özet İçerik — 3-Kategori Yapılandırılmış Görünüm
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary, required this.tts});
  final MedicationSummary summary;
  final _TtsController tts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: _buildCards(summary, tts),
    );
  }
}

/// Hem tam ekran hem alt sheet tarafından paylaşılan kart listesi.
List<Widget> _buildCards(MedicationSummary s, _TtsController tts) => [
      _HeaderCard(summary: s),
      const SizedBox(height: 16),
      _CategoryCard(
        emoji: '🌟',
        title: 'Temel Faydası',
        subtitle: 'Bu ilaç ne için kullanılır?',
        bullets: s.temelFaydasi,
        accentColor: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
        tts: tts,
        cardId: 'temel',
      ),
      const SizedBox(height: 10),
      _CategoryCard(
        emoji: '🥄',
        title: 'Kullanım Şekli',
        subtitle: 'Nasıl ve ne kadar kullanılır?',
        bullets: s.kullanimSekli,
        accentColor: const Color(0xFF2E7D32),
        bgColor: const Color(0xFFE8F5E9),
        tts: tts,
        cardId: 'kullanim',
      ),
      const SizedBox(height: 10),
      _CategoryCard(
        emoji: '⚠️',
        title: 'Dikkat Edilecekler',
        subtitle: 'Uyarılar ve olası yan etkiler',
        bullets: s.dikkatEdilecekler,
        accentColor: const Color(0xFFBF360C),
        bgColor: const Color(0xFFFFF3E0),
        tts: tts,
        cardId: 'dikkat',
      ),
      const SizedBox(height: 18),
      _DisclaimerCard(disclaimer: s.disclaimer),
    ];

// ─────────────────────────────────────────────────────────────────────────────
// Header Kartı: İlaç adı + etkin madde + ATC + kategori + özet metodu
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary});
  final MedicationSummary summary;

  @override
  Widget build(BuildContext context) {
    final isAI = summary.summaryMethod == 'transformers';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1A237E),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İlaç adı
            Text(
              summary.productName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            if (summary.activeIngredient != null &&
                summary.activeIngredient!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.science_rounded,
                label: 'Etkin Madde',
                value: summary.activeIngredient!,
                color: Colors.white70,
              ),
            ],
            if (summary.atcCode != null && summary.atcCode!.isNotEmpty) ...[
              const SizedBox(height: 2),
              _InfoRow(
                icon: Icons.qr_code_rounded,
                label: 'ATC',
                value: summary.atcCode!,
                color: Colors.white70,
              ),
            ],
            if (summary.category != null && summary.category!.isNotEmpty) ...[
              const SizedBox(height: 2),
              _InfoRow(
                icon: Icons.category_rounded,
                label: 'Kategori',
                value: summary.category!,
                color: Colors.white70,
              ),
            ],
            const SizedBox(height: 12),
            // AI badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isAI
                    ? const Color(0xFF0288D1).withOpacity(0.9)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAI ? Icons.auto_awesome : Icons.rule_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isAI ? 'Yapay Zeka Özetledi' : 'Kural Tabanlı Özet',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bölüm Kartı: İkon, başlık, içerik + isteğe bağlı chip listesi
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
    required this.content,
    this.chips = const [],
    this.chipsLabel,
    this.chipColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String subtitle;
  final String content;
  final List<String> chips;
  final String? chipsLabel;
  final Color? chipColor;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.iconColor, size: 22),
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: widget.iconColor,
            ),
          ),
          subtitle: Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          children: [
            // Ana metin
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.backgroundColor.withOpacity(0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: Color(0xFF212121),
                ),
              ),
            ),

            // Chip listesi (NER etiketleri)
            if (widget.chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.chipsLabel ?? 'Tespit Edilenler',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.chipColor ?? widget.iconColor,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: widget.chips
                    .map(
                      (chip) => Chip(
                        label: Text(
                          chip,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor:
                            widget.chipColor ?? widget.iconColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 0,
                        ),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-Kategori Kart: emoji başlık + maddeler listesi
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.accentColor,
    required this.bgColor,
    this.tts,
    this.cardId = '',
  });

  final String emoji;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final Color accentColor;
  final Color bgColor;
  final _TtsController? tts;
  final String cardId;

  String get _readText {
    final content = bullets.isEmpty ? 'Bilgi bulunamadı.' : bullets.join('. ');
    return '$title. $content';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık şeridi ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  left: BorderSide(color: accentColor, width: 4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: accentColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Sesli Dinle butonu ──────────────────────────────────
                  if (tts != null)
                    ListenableBuilder(
                      listenable: tts!,
                      builder: (_, __) {
                        final active = tts!.isSpeaking(cardId);
                        return Tooltip(
                          message: active ? 'Durdur' : 'Sesli Dinle',
                          child: InkWell(
                            onTap: () => tts!.toggle(cardId, _readText),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: active
                                    ? accentColor.withOpacity(0.15)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                active
                                    ? Icons.stop_circle_rounded
                                    : Icons.volume_up_rounded,
                                color: accentColor,
                                size: 22,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            // ── Madde listesi ─────────────────────────────────────────────
            if (bullets.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Bilgi bulunamadı.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else if (bullets.length == 1 &&
                bullets.first == _kProspectusUnavailable)
              // ── Profesyonel fallback banner (boş ekran gösterilmez) ──────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.update_rounded,
                        color: accentColor.withOpacity(0.7),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _kProspectusUnavailable,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: accentColor.withOpacity(0.85),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  children: bullets.map((bullet) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 10),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              bullet,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.55,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YZ Sorumluluk Reddi Kartı (Rapor 5.2)
// ─────────────────────────────────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard({required this.disclaimer});
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD600), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              disclaimer,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF5D4037),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yükleniyor Görünümü
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Yapay Zeka Özetleniyor...',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Prospektüs analiz ediliyor',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hata Görünümü
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Color(0xFFB0BEC5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Özet alınamadı',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF78909C)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet Widget — Scaffold olmadan, DraggableScrollableSheet içinde
// ─────────────────────────────────────────────────────────────────────────────

class _MedSummarySheet extends StatefulWidget {
  final int? medicationId;
  final int? globalMedId;
  final String? medicationName;

  const _MedSummarySheet({
    this.medicationId,
    this.globalMedId,
    this.medicationName,
  });

  @override
  State<_MedSummarySheet> createState() => _MedSummarySheetState();
}

class _MedSummarySheetState extends State<_MedSummarySheet> {
  late Future<MedicationSummary> _summaryFuture;
  late final _TtsController _tts;

  @override
  void initState() {
    super.initState();
    _tts = _TtsController();
    _tts.init();
    _summaryFuture = _fetchSummary();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<MedicationSummary> _fetchSummary() {
    final api = context.read<ApiService>();
    if (widget.medicationId != null) {
      return api.summarizeMedication(widget.medicationId!);
    }
    return api.summarizeGlobalMedication(widget.globalMedId!);
  }

  void _reload() => setState(() => _summaryFuture = _fetchSummary());

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Sürükleme tutamacı
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Başlık satırı
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFF1A237E), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.medicationName ?? 'İlaç Bilgisi',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A237E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _SpeedButton(tts: _tts),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _reload,
                    tooltip: 'Yenile',
                    color: const Color(0xFF1A237E),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // İçerik
            Expanded(
              child: FutureBuilder<MedicationSummary>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _LoadingView();
                  }
                  if (snapshot.hasError) {
                    return _ErrorView(
                      error: snapshot.error is ApiException
                          ? (snapshot.error as ApiException).message
                          : snapshot.error.toString(),
                      onRetry: _reload,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text('Veri bulunamadı.'));
                  }
                  final summary = snapshot.data!;
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: _buildCards(summary, _tts),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
