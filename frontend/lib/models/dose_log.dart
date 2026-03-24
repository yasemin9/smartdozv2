/// SmartDoz - Doz Log Modeli (Modül 2)
class DoseLog {
  final int id;
  final int medicationId;
  final String medicationName;
  final String dosageForm;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final String status; // Bekliyor | Alındı | Atlandı | Ertelendi | Planlandı
  final String? notes;

  const DoseLog({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.dosageForm,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
    this.notes,
  });

  factory DoseLog.fromJson(Map<String, dynamic> json) => DoseLog(
        id: json['id'] as int,
        medicationId: json['medication_id'] as int,
        medicationName: json['medication_name'] as String,
        dosageForm: json['dosage_form'] as String,
        scheduledTime: DateTime.parse(json['scheduled_time'] as String),
        actualTime: json['actual_time'] != null
            ? DateTime.parse(json['actual_time'] as String)
            : null,
        status: json['status'] as String,
        notes: json['notes'] as String?,
      );

  /// 30 dakikadan fazla gecikmeli ve hâlâ Bekliyor
  bool get isOverdue =>
      status == 'Bekliyor' &&
      scheduledTime.isBefore(DateTime.now().subtract(const Duration(minutes: 30)));

  /// 30 dakika içinde zamanı gelecek Bekliyor doz
  bool get isUpcoming =>
      status == 'Bekliyor' &&
      scheduledTime.isAfter(DateTime.now()) &&
      scheduledTime.isBefore(DateTime.now().add(const Duration(minutes: 30)));

  bool get isTaken    => status == 'Alındı';
  bool get isMissed   => status == 'Atlandı';
  bool get isPostponed => status == 'Ertelendi';
  bool get isPending   => status == 'Bekliyor';
  bool get isPlanned   => status == 'Planlandı';
}
