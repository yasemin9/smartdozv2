/// SmartDoz - Kullanıcı Tercihi Modeli (Modül 2)
///
/// ZAMANDILIMIHESAPLA algoritmasının girdi parametrelerini tutar.
class UserPreference {
  /// "HH:mm:ss" formatında uyanma saati
  final String wakeTime;

  /// "HH:mm:ss" formatında uyku saati
  final String sleepTime;

  const UserPreference({
    required this.wakeTime,
    required this.sleepTime,
  });

  factory UserPreference.fromJson(Map<String, dynamic> json) => UserPreference(
        wakeTime: json['wake_time'] as String,
        sleepTime: json['sleep_time'] as String,
      );

  Map<String, dynamic> toJson() => {
        'wake_time': wakeTime,
        'sleep_time': sleepTime,
      };

  /// Gösterim için saat ve dakika (ör. "08:00")
  String get wakeDisplay  => wakeTime.substring(0, 5);
  String get sleepDisplay => sleepTime.substring(0, 5);
}
