/// SmartDoz - İlaç modeli (API yanıtına karşılık gelir)
class Medication {
  final int? id;
  final int? userId;
  final String name;
  final String dosageForm;
  final String usageFrequency;
  final String usageTime;
  final DateTime expiryDate;

  const Medication({
    this.id,
    this.userId,
    required this.name,
    required this.dosageForm,
    required this.usageFrequency,
    required this.usageTime,
    required this.expiryDate,
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as int?,
        userId: json['user_id'] as int?,
        name: json['name'] as String,
        dosageForm: json['dosage_form'] as String,
        usageFrequency: json['usage_frequency'] as String,
        usageTime: json['usage_time'] as String,
        expiryDate: DateTime.parse(json['expiry_date'] as String),
      );

  /// Backend'e gönderilecek JSON (id/userId dahil edilmez)
  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage_form': dosageForm,
        'usage_frequency': usageFrequency,
        'usage_time': usageTime,
        'expiry_date':
            '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
      };

  /// Son kullanma tarihi bugün veya geçmişte mi?
  bool get isExpired =>
      expiryDate.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0));
}
