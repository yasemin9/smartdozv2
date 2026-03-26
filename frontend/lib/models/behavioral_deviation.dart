/// SmartDoz - Modül 7: Davranışsal Sapma Modeli
///
/// Kullanıcının atlanmış dozlarının saate ve haftanın gününe göre
/// dağılımını temsil eder. Backend /analytics/behavioral-deviation yanıtıyla eşleşir.

/// Saat dilimine göre atlanmış doz sayısı.
class MissedHourSlot {
  final int hour;          // 0–23
  final int missedCount;

  const MissedHourSlot({required this.hour, required this.missedCount});

  factory MissedHourSlot.fromJson(Map<String, dynamic> json) => MissedHourSlot(
        hour: json['hour'] as int,
        missedCount: json['missed_count'] as int,
      );

  /// Saat etiketini "08:00" formatında döner.
  String get hourLabel =>
      '${hour.toString().padLeft(2, '0')}:00';
}

/// Haftanın gününe göre atlanmış doz sayısı.
class MissedDaySlot {
  final int dayOfWeek;   // 0=Pazartesi … 6=Pazar
  final String dayName;  // Türkçe gün adı
  final int missedCount;

  const MissedDaySlot({
    required this.dayOfWeek,
    required this.dayName,
    required this.missedCount,
  });

  factory MissedDaySlot.fromJson(Map<String, dynamic> json) => MissedDaySlot(
        dayOfWeek: json['day_of_week'] as int,
        dayName: json['day_name'] as String,
        missedCount: json['missed_count'] as int,
      );
}

/// Son N günlük davranışsal sapma analizi özeti.
class BehavioralDeviation {
  final int periodDays;
  final int totalSkipped;
  final List<MissedHourSlot> missedByHour;  // Büyükten küçüğe sıralı
  final List<MissedDaySlot> missedByDay;    // Büyükten küçüğe sıralı
  final int? peakMissHour;    // En çok kaçırılan saat (0–23), veri yoksa null
  final String? peakMissDay;  // En çok kaçırılan gün adı, veri yoksa null

  const BehavioralDeviation({
    required this.periodDays,
    required this.totalSkipped,
    required this.missedByHour,
    required this.missedByDay,
    this.peakMissHour,
    this.peakMissDay,
  });

  factory BehavioralDeviation.fromJson(Map<String, dynamic> json) =>
      BehavioralDeviation(
        periodDays: json['period_days'] as int,
        totalSkipped: json['total_skipped'] as int,
        missedByHour: (json['missed_by_hour'] as List<dynamic>)
            .map((e) => MissedHourSlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        missedByDay: (json['missed_by_day'] as List<dynamic>)
            .map((e) => MissedDaySlot.fromJson(e as Map<String, dynamic>))
            .toList(),
        peakMissHour: json['peak_miss_hour'] as int?,
        peakMissDay: json['peak_miss_day'] as String?,
      );

  bool get hasData => totalSkipped > 0;
}
