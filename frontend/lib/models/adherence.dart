/// SmartDoz - Modül 7: Tedavi Uyumu Modelleri

/// Bir haftaya ait uyum verisi (fl_chart LineChart için kullanılır).
class WeeklyTrendPoint {
  final String weekLabel;   // Ör. "Hafta 05"
  final String weekStart;   // ISO 8601, ör. "2025-01-27"
  final int planned;
  final int taken;
  final int skipped;
  final int postponed;
  final double adherenceScore; // 0.0 – 1.0

  const WeeklyTrendPoint({
    required this.weekLabel,
    required this.weekStart,
    required this.planned,
    required this.taken,
    required this.skipped,
    required this.postponed,
    required this.adherenceScore,
  });

  factory WeeklyTrendPoint.fromJson(Map<String, dynamic> json) =>
      WeeklyTrendPoint(
        weekLabel: json['week_label'] as String,
        weekStart: json['week_start'] as String,
        planned: json['planned'] as int,
        taken: json['taken'] as int,
        skipped: json['skipped'] as int,
        postponed: json['postponed'] as int,
        adherenceScore: (json['adherence_score'] as num).toDouble(),
      );

  /// Yüzde olarak skor (0–100)
  double get scorePercent => adherenceScore * 100;
}

/// Son N günlük MPR tabanlı tedavi uyum özeti.
class AdherenceSummary {
  final String periodStart;
  final String periodEnd;
  final int totalPlanned;
  final int totalTaken;
  final int totalSkipped;
  final int totalPostponed;
  final double adherenceScore; // 0.0 – 1.0
  final List<WeeklyTrendPoint> weeklyTrend;

  const AdherenceSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalPlanned,
    required this.totalTaken,
    required this.totalSkipped,
    required this.totalPostponed,
    required this.adherenceScore,
    required this.weeklyTrend,
  });

  factory AdherenceSummary.fromJson(Map<String, dynamic> json) =>
      AdherenceSummary(
        periodStart: json['period_start'] as String,
        periodEnd: json['period_end'] as String,
        totalPlanned: json['total_planned'] as int,
        totalTaken: json['total_taken'] as int,
        totalSkipped: json['total_skipped'] as int,
        totalPostponed: json['total_postponed'] as int,
        adherenceScore: (json['adherence_score'] as num).toDouble(),
        weeklyTrend: (json['weekly_trend'] as List<dynamic>)
            .map((e) =>
                WeeklyTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Skoru 0–100 yüzde olarak döner.
  double get scorePercent => adherenceScore * 100;

  /// Uyum seviyesini kategorik olarak döner.
  String get scoreLabel {
    if (adherenceScore >= 0.80) return 'Yüksek';
    if (adherenceScore >= 0.50) return 'Orta';
    return 'Düşük';
  }
}
