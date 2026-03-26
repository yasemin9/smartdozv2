/// SmartDoz - Modül 7: Haftalık Uyum Trendi Ekranı
///
/// fl_chart LineChart ile son 30 günün haftalık MPR skorunu
/// interaktif ve vektörel olarak gösterir.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/adherence.dart';
import '../models/behavioral_deviation.dart';
import '../services/api_service.dart';

class AdherenceScreen extends StatefulWidget {
  const AdherenceScreen({super.key});

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  late Future<AdherenceSummary> _summaryFuture;
  late Future<BehavioralDeviation> _deviationFuture;
  int _selectedDays = 30;
  int? _touchedIndex;
  late ApiService _apiService;

  static const _periodOptions = [7, 14, 30, 90];

  @override
  void initState() {
    super.initState();
    _apiService = context.read<ApiService>();
    _load();
    // ApiService bir doz güncellendiğinde (updateDoseStatus → notifyListeners)
    // bu ekran otomatik olarak yenilenir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiService.addListener(_onDoseUpdated);
    });
  }

  @override
  void dispose() {
    _apiService.removeListener(_onDoseUpdated);
    super.dispose();
  }

  void _onDoseUpdated() {
    if (mounted) setState(_load);
  }

  void _load() {
    _summaryFuture = _apiService.getAdherenceSummary(
          days: _selectedDays,
        );
    _deviationFuture = _apiService.getBehavioralDeviation(
          days: _selectedDays,
        );
  }

  void _onPeriodChanged(int days) {
    if (days == _selectedDays) return;
    setState(() {
      _selectedDays = days;
      _touchedIndex = null;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık Uyum Trendi'),
        centerTitle: true,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Periyot Seçici ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Periyot: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ..._periodOptions.map((d) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$d Gün'),
                        selected: _selectedDays == d,
                        onSelected: (_) => _onPeriodChanged(d),
                        selectedColor:
                            colorScheme.primary.withValues(alpha: 0.18),
                      ),
                    )),
              ],
            ),
          ),
          // ── İçerik ──────────────────────────────────
          Expanded(
            child: FutureBuilder<AdherenceSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildNetworkError(context, snapshot.error);
                }

                final summary = snapshot.data!;
                return _buildContent(context, summary, colorScheme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AdherenceSummary summary,
    ColorScheme colorScheme,
  ) {
    final hasData = summary.totalPlanned > 0;

    return RefreshIndicator(
      onRefresh: () async => setState(_load),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasData)
            _NoDataCard(days: _selectedDays)
          else ...[
          // ── Özet Kart ─────────────────────────────
          _SummaryCard(summary: summary, colorScheme: colorScheme),
          const SizedBox(height: 20),
          // ── Çizgi Grafik ──────────────────────────
          if (summary.weeklyTrend.isEmpty)
            _EmptyTrendCard(days: _selectedDays)
          else ...[
            Text(
              'Haftalık Uyum Oranı (%)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _AdherenceLineChart(
              trend: summary.weeklyTrend,
              colorScheme: colorScheme,
              touchedIndex: _touchedIndex,
              onTouch: (idx) => setState(() => _touchedIndex = idx),
            ),
            const SizedBox(height: 20),
            // ── Haftalık Tablo ───────────────────────
            _WeeklyTable(trend: summary.weeklyTrend, colorScheme: colorScheme),
          ],
          const SizedBox(height: 24),
          // ── Davranışsal Sapma ─────────────────────
          FutureBuilder<BehavioralDeviation>(
            future: _deviationFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError || snap.data == null) {
                return const SizedBox.shrink();
              }
              return _BehavioralDeviationSection(
                deviation: snap.data!,
                colorScheme: colorScheme,
              );
            },
          ),
        ],  // else ...[hasData] kapanıyor
        ],  // children: [ kapanıyor
      ),
    );
  }

  /// Ağ hatası veya sunucu cevapsızlığı durumunda gösterilen hata kartı.
  Widget _buildNetworkError(BuildContext context, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Veriye ulaşılamadı',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sunucu bağlantısını kontrol edin ve tekrar deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Veri Yok Bilgilendirme Kartı
// ──────────────────────────────────────────────────────

class _NoDataCard extends StatelessWidget {
  final int days;
  const _NoDataCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İllustrasyon ikonu
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_graph_rounded,
                size: 46,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz analiz yapacak kadar\nveri birikmedi',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Akıllı grafiklerin oluşması için birkaç gün daha '
              'düzenli kayıt girmeye devam et!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // İpcuçları
            _TipRow(
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green.shade600,
              text: 'İlaçlarını zamanında "Alındı" olarak işaretle',
            ),
            const SizedBox(height: 8),
            _TipRow(
              icon: Icons.calendar_today_outlined,
              color: colorScheme.primary,
              text: 'Son $days gün için en az 1 haftalık veri gereklidir',
            ),
            const SizedBox(height: 8),
            _TipRow(
              icon: Icons.insights_rounded,
              color: Colors.orange.shade700,
              text: 'Grafik otomatik olarak güncellenir',
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _TipRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// Özet Kart
// ──────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final AdherenceSummary summary;
  final ColorScheme colorScheme;

  const _SummaryCard({required this.summary, required this.colorScheme});

  /// %50 altı: Eşik Kritik (rapor s.45)
  bool get _isCritical => summary.adherenceScore < 0.50;

  Color get _scoreColor {
    if (summary.adherenceScore >= 0.80) return Colors.green.shade600;
    if (summary.adherenceScore >= 0.50) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Color get _borderColor {
    if (summary.adherenceScore >= 0.50) return Colors.green.shade500;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: _isCritical ? 4 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _borderColor, width: 2),
      ),
      color: _isCritical ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Eşik Kritik uyarı metni
            if (_isCritical) ...
              [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Uyum oranın kritik eşiğin altında!',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            // Büyük skor dairesi
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: CircularProgressIndicator(
                    value: summary.adherenceScore,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_scoreColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${summary.scorePercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor,
                      ),
                    ),
                    Text(
                      summary.scoreLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: _scoreColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${summary.periodStart} – ${summary.periodEnd}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            // İstatistik satırı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatChip(
                  label: 'Planlanan',
                  value: summary.totalPlanned,
                  color: Colors.grey.shade600,
                ),
                _StatChip(
                  label: 'Alındı',
                  value: summary.totalTaken,
                  color: Colors.green.shade600,
                ),
                _StatChip(
                  label: 'Atlandı',
                  value: summary.totalSkipped,
                  color: Colors.red.shade500,
                ),
                _StatChip(
                  label: 'Ertelendi',
                  value: summary.totalPostponed,
                  color: Colors.orange.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// İnteraktif Çizgi Grafik
// ──────────────────────────────────────────────────────

class _AdherenceLineChart extends StatelessWidget {
  final List<WeeklyTrendPoint> trend;
  final ColorScheme colorScheme;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;

  const _AdherenceLineChart({
    required this.trend,
    required this.colorScheme,
    required this.touchedIndex,
    required this.onTouch,
  });

  List<FlSpot> get _spots => [
        for (var i = 0; i < trend.length; i++)
          FlSpot(i.toDouble(), trend[i].adherenceScore * 100),
      ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = colorScheme.primary;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          // Dokunma etkileşimi: tooltip ve nokta büyütme
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchCallback: (FlTouchEvent event, LineTouchResponse? resp) {
              if (!event.isInterestedForInteractions ||
                  resp == null ||
                  resp.lineBarSpots == null) {
                onTouch(null);
                return;
              }
              onTouch(resp.lineBarSpots!.first.spotIndex);
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  colorScheme.primary.withValues(alpha: 0.85),
              getTooltipItems: (spots) => spots.map((spot) {
                final pt = trend[spot.spotIndex];
                return LineTooltipItem(
                  '${pt.weekLabel}\n%${pt.scorePercent.toStringAsFixed(0)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text:
                          '\nAlındı: ${pt.taken}  Atlandı: ${pt.skipped}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),

          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 25,
                getTitlesWidget: (value, meta) => Text(
                  '%${value.toInt()}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= trend.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      // "16/03 - 22/03" formatından sadece baş tarihi göster
                      trend[idx].weekLabel.split(' - ').first,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),

          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
              left: BorderSide(color: Colors.grey.shade300),
            ),
          ),

          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          minY: 0,
          maxY: 100,

          lineBarsData: [
            LineChartBarData(
              spots: _spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final isTouched = index == touchedIndex;
                  return FlDotCirclePainter(
                    radius: isTouched ? 7 : 4,
                    color: isTouched ? Colors.white : primaryColor,
                    strokeWidth: isTouched ? 3 : 1.5,
                    strokeColor: primaryColor,
                  );
                },
              ),
              // Gradyan dolgu
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.3),
                    primaryColor.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Haftalık Detay Tablosu
// ──────────────────────────────────────────────────────

class _WeeklyTable extends StatelessWidget {
  final List<WeeklyTrendPoint> trend;
  final ColorScheme colorScheme;

  const _WeeklyTable({required this.trend, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Haftalık Detaylar',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            // Başlık satırı
            const _TableRow(
              weekLabel: 'Hafta',
              planned: 'Plan',
              taken: 'Alındı',
              skipped: 'Atlandı',
              score: 'Uyum',
              isHeader: true,
            ),
            const Divider(height: 1),
            ...trend.map(
              (pt) => _TableRow(
                weekLabel: pt.weekLabel,
                planned: '${pt.planned}',
                taken: '${pt.taken}',
                skipped: '${pt.skipped}',
                score: '%${pt.scorePercent.toStringAsFixed(0)}',
                scoreColor: _scoreColor(pt.adherenceScore),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.80) return Colors.green.shade600;
    if (score >= 0.50) return Colors.orange.shade700;
    return Colors.red.shade600;
  }
}

class _TableRow extends StatelessWidget {
  final String weekLabel;
  final String planned;
  final String taken;
  final String skipped;
  final String score;
  final bool isHeader;
  final Color? scoreColor;

  const _TableRow({
    required this.weekLabel,
    required this.planned,
    required this.taken,
    required this.skipped,
    required this.score,
    this.isHeader = false,
    this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)
        : const TextStyle(fontSize: 12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(weekLabel, style: style)),
          SizedBox(
              width: 44,
              child: Text(planned,
                  style: style, textAlign: TextAlign.center)),
          SizedBox(
              width: 52,
              child: Text(taken,
                  style: style.copyWith(
                      color: isHeader ? null : Colors.green.shade600),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 52,
              child: Text(skipped,
                  style: style.copyWith(
                      color: isHeader ? null : Colors.red.shade500),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 52,
              child: Text(score,
                  style: style.copyWith(
                      color: isHeader ? null : scoreColor,
                      fontWeight: isHeader
                          ? FontWeight.w700
                          : FontWeight.w600),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Boş Durum
// ──────────────────────────────────────────────────────

class _EmptyTrendCard extends StatelessWidget {
  final int days;
  const _EmptyTrendCard({required this.days});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Son $days günde kayıt bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Davranışsal Sapma Bölümü
// ──────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────
// Renk yardımcısı: orana göre yeşil → sarı → turuncu → kırmızı
// ──────────────────────────────────────────────────────
Color _riskColor(double ratio) {
  if (ratio <= 0.0) return Colors.green.shade400;
  if (ratio < 0.35) return Colors.lightGreen.shade500;
  if (ratio < 0.60) return Colors.orange.shade400;
  if (ratio < 0.85) return Colors.deepOrange.shade500;
  return Colors.red.shade600;
}

// ──────────────────────────────────────────────────────
// Davranışsal Sapma Ana Bölümü
// ──────────────────────────────────────────────────────

class _BehavioralDeviationSection extends StatelessWidget {
  final BehavioralDeviation deviation;
  final ColorScheme colorScheme;

  const _BehavioralDeviationSection({
    required this.deviation,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Bölüm başlığı ─────────────────────────────
        Row(
          children: [
            Icon(Icons.psychology_alt_rounded,
                size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Risk Analizi',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Son ${deviation.periodDays} günde ilaç aksatma örüntüleri',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),

        if (!deviation.hasData)
          _DeviationEmptyCard(colorScheme: colorScheme)
        else ...[
          // ── Özet kart ─────────────────────────────
          _DeviationSummaryRow(deviation: deviation),
          const SizedBox(height: 20),

          // ── Saat analizi ──────────────────────────
          if (deviation.missedByHour.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.access_time_rounded,
              title: 'Aksatılan Dozların Zaman Analizi',
              subtitle: 'En çok aksatılan saat dilimleri (büyükten küçüğe)',
            ),
            const SizedBox(height: 10),
            _HourBarChart(
              slots: deviation.missedByHour,
              totalSkipped: deviation.totalSkipped,
            ),
            const SizedBox(height: 20),
          ],

          // ── Gün analizi ───────────────────────────
          if (deviation.missedByDay.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.calendar_today_rounded,
              title: 'Haftanın En Riskli Günleri',
              subtitle: 'Günlere göre aksatma dağılımı',
            ),
            const SizedBox(height: 10),
            _DayBarChart(
              slots: deviation.missedByDay,
              totalSkipped: deviation.totalSkipped,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// Bölüm başlığı widget'ı
// ──────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// Özet satırı
// ──────────────────────────────────────────────────────
class _DeviationSummaryRow extends StatelessWidget {
  final BehavioralDeviation deviation;

  const _DeviationSummaryRow({required this.deviation});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _DeviationChip(
              icon: Icons.block_rounded,
              label: 'Toplam Aksatılan',
              value: '${deviation.totalSkipped}',
              color: Colors.red.shade700,
            ),
            if (deviation.peakMissHour != null) ...[
              _VerticalDivider(),
              _DeviationChip(
                icon: Icons.access_time_filled_rounded,
                label: 'En Riskli Saat',
                value:
                    '${deviation.peakMissHour.toString().padLeft(2, '0')}:00',
                color: Colors.deepOrange.shade600,
              ),
            ],
            if (deviation.peakMissDay != null) ...[
              _VerticalDivider(),
              _DeviationChip(
                icon: Icons.event_busy_rounded,
                label: 'En Riskli Gün',
                value: deviation.peakMissDay!,
                color: Colors.orange.shade800,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 36,
        width: 1,
        color: Colors.red.shade100,
      );
}

class _DeviationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DeviationChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// Saat bazlı bar grafiği — renk kodlu + tooltip
// ──────────────────────────────────────────────────────
class _HourBarChart extends StatelessWidget {
  final List<MissedHourSlot> slots;
  final int totalSkipped;

  const _HourBarChart({
    required this.slots,
    required this.totalSkipped,
  });

  @override
  Widget build(BuildContext context) {
    final top = slots.take(8).toList();
    final maxCount =
        top.fold(0, (m, s) => s.missedCount > m ? s.missedCount : m);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 10),
        child: Column(
          children: top.map((slot) {
            final ratio =
                maxCount == 0 ? 0.0 : slot.missedCount / maxCount;
            final pct = totalSkipped == 0
                ? 0
                : (slot.missedCount / totalSkipped * 100).round();
            final barColor = _riskColor(ratio);
            final tooltip =
                'Bu saatte %$pct oranında aksatma yaşıyorsunuz';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Saat etiketi + sayac
                  Row(
                    children: [
                      Text(
                        slot.hourLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${slot.missedCount} kez  •  %$pct',
                        style: TextStyle(
                            fontSize: 11,
                            color: barColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Çubuk
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 20,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: 20,
                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  // Tooltip açıklaması
                  Text(
                    tooltip,
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Gün bazlı bar grafiği — renk kodlu + tooltip
// ──────────────────────────────────────────────────────
class _DayBarChart extends StatelessWidget {
  final List<MissedDaySlot> slots;
  final int totalSkipped;

  const _DayBarChart({
    required this.slots,
    required this.totalSkipped,
  });

  @override
  Widget build(BuildContext context) {
    // Pazartesi → Pazar sırasında göster
    final ordered = List<MissedDaySlot>.from(slots)
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    final maxCount =
        ordered.fold(0, (m, s) => s.missedCount > m ? s.missedCount : m);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 10),
        child: Column(
          children: ordered.map((slot) {
            final ratio =
                maxCount == 0 ? 0.0 : slot.missedCount / maxCount;
            final pct = totalSkipped == 0
                ? 0
                : (slot.missedCount / totalSkipped * 100).round();
            final barColor = _riskColor(ratio);
            final isZero = slot.missedCount == 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Gün adı
                      SizedBox(
                        width: 90,
                        child: Text(
                          slot.dayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isZero
                                ? Colors.green.shade600
                                : barColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      isZero
                          ? Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 13,
                                    color: Colors.green.shade600),
                                const SizedBox(width: 4),
                                Text('Sorunsuz',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w600)),
                              ],
                            )
                          : Text(
                              '${slot.missedCount} kez  •  %$pct',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: barColor,
                                  fontWeight: FontWeight.w600),
                            ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 20,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: 20,
                            width: constraints.maxWidth *
                                (isZero ? 0.0 : ratio),
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 3),
                  // Tooltip
                  Text(
                    isZero
                        ? 'Bu günde hiç aksatma yaşanmadı 🎉'
                        : 'Bu günde toplam aksatmanın %$pct\'i gerçekleşti',
                    style: TextStyle(
                        fontSize: 10.5, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Veri yok durumu
// ──────────────────────────────────────────────────────
class _DeviationEmptyCard extends StatelessWidget {
  final ColorScheme colorScheme;
  const _DeviationEmptyCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration_rounded,
                size: 28, color: Colors.green.shade600),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Bu dönemde hiç doz aksatılmadı. Harika gidiyorsun!',
                style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

