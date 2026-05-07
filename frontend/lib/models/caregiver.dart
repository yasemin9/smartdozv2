/// SmartDoz - Caregiver Modeli
class Caregiver {
  final int id;
  final int userId;
  final int caregiverUserId;
  final String caregiverName;
  final String caregiverEmail;
  final String relationshipType;
  final bool isActive;
  final DateTime createdAt;

  Caregiver({
    required this.id,
    required this.userId,
    required this.caregiverUserId,
    required this.caregiverName,
    required this.caregiverEmail,
    required this.relationshipType,
    required this.isActive,
    required this.createdAt,
  });

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      caregiverUserId: json['caregiver_user_id'] as int,
      caregiverName: json['caregiver_name'] as String? ?? '',
      caregiverEmail: json['caregiver_email'] as String? ?? '',
      relationshipType: json['relationship_type'] as String? ?? 'caregiver',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'caregiver_user_id': caregiverUserId,
    'relationship_type': relationshipType,
    'is_active': isActive,
  };
}
