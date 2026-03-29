/// SmartDoz - Kullanıcı Tercihi Modeli (Modül 2)
///
/// ZAMANDILIMIHESAPLA algoritmasının girdi parametrelerini ve
/// günlük rutin saatlerini (Kahvaltı, Öğle, Akşam, Yatış) tutar.
class UserPreference {
  /// "HH:mm:ss" formatında uyanma saati
  final String wakeTime;

  /// "HH:mm:ss" formatında uyku saati
  final String sleepTime;

  /// Günlük rutin saatler — null ise kullanıcı henüz tanımlamamış
  final String? breakfastTime;
  final String? lunchTime;
  final String? dinnerTime;
  final String? bedtime;

  const UserPreference({
    required this.wakeTime,
    required this.sleepTime,
    this.breakfastTime,
    this.lunchTime,
    this.dinnerTime,
    this.bedtime,
  });

  factory UserPreference.fromJson(Map<String, dynamic> json) => UserPreference(
        wakeTime:      json['wake_time']      as String,
        sleepTime:     json['sleep_time']     as String,
        breakfastTime: json['breakfast_time'] as String?,
        lunchTime:     json['lunch_time']     as String?,
        dinnerTime:    json['dinner_time']    as String?,
        bedtime:       json['bedtime']        as String?,
      );

  Map<String, dynamic> toJson() => {
        'wake_time':      wakeTime,
        'sleep_time':     sleepTime,
        'breakfast_time': breakfastTime,
        'lunch_time':     lunchTime,
        'dinner_time':    dinnerTime,
        'bedtime':        bedtime,
      };

  /// Gösterim için saat ve dakika (ör. "08:00")
  String get wakeDisplay  => wakeTime.substring(0, 5);
  String get sleepDisplay => sleepTime.substring(0, 5);

  /// Rutinin tamamen tanımlanıp tanımlanmadığı
  bool get hasRoutine =>
      breakfastTime != null &&
      lunchTime     != null &&
      dinnerTime    != null &&
      bedtime       != null;
}
