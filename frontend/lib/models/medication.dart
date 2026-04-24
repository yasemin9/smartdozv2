/// SmartDoz - İlaç modeli (API yanıtına karşılık gelir)
class InteractionWarning {
  final String withMedicationName;
  final String description;

  const InteractionWarning({
    required this.withMedicationName,
    required this.description,
  });

  factory InteractionWarning.fromJson(Map<String, dynamic> json) =>
      InteractionWarning(
        withMedicationName: json['with_medication_name'] as String,
        description: json['description'] as String,
      );
}

class CriticalInteractionWarning {
  final String riskLevel;
  final String title;
  final String message;
  final String medicationA;
  final String medicationB;
  final String atcA;
  final String atcB;
  final String description;

  const CriticalInteractionWarning({
    required this.riskLevel,
    required this.title,
    required this.message,
    required this.medicationA,
    required this.medicationB,
    required this.atcA,
    required this.atcB,
    required this.description,
  });

  factory CriticalInteractionWarning.fromJson(Map<String, dynamic> json) =>
      CriticalInteractionWarning(
        riskLevel: json['risk_level'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        medicationA: json['medication_a'] as String,
        medicationB: json['medication_b'] as String,
        atcA: json['atc_a'] as String,
        atcB: json['atc_b'] as String,
        description: json['description'] as String,
      );
}

class Medication {
  final int? id;
  final int? userId;
  final String name;
  final String dosageForm;
  final String usageFrequency;
  final String usageTime;
  final DateTime expiryDate;
  final String? activeIngredient;
  final String? atcCode;
  final String? barcode;
  final List<InteractionWarning> interactionWarnings;
  final String? prospectusLink; // Soru işareti null olabileceği anlamına gelir

  const Medication({
    this.id,
    this.userId,
    required this.name,
    required this.dosageForm,
    required this.usageFrequency,
    required this.usageTime,
    required this.expiryDate,
    this.activeIngredient,
    this.atcCode,
    this.barcode,
    this.prospectusLink,
    this.interactionWarnings = const [],
  });

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as int?,
        userId: json['user_id'] as int?,
        name: json['name'] as String,
        dosageForm: json['dosage_form'] as String,
        usageFrequency: json['usage_frequency'] as String,
        usageTime: json['usage_time'] as String,
        expiryDate: DateTime.parse(json['expiry_date'] as String),
        activeIngredient: json['active_ingredient'] as String?,
        atcCode: json['atc_code'] as String?,
        prospectusLink: json['prospectus_link'],
        barcode: json['barcode'] as String?,
        interactionWarnings: ((json['interaction_warnings'] as List<dynamic>?) ?? [])
            .map((e) => InteractionWarning.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Backend'e gönderilecek JSON (id/userId dahil edilmez)
  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage_form': dosageForm,
        'usage_frequency': usageFrequency,
        'usage_time': usageTime,
        'active_ingredient': activeIngredient,
        'atc_code': atcCode,
        'barcode': barcode,
        'prospectus_link': prospectusLink,
        'expiry_date':
            '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
      };

  /// Son kullanma tarihi bugün veya geçmişte mi?
  bool get isExpired =>
      expiryDate.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0));
}
