// SmartDoz - Modül 8: YZ Karar Modelleri
//
// Backend /ai/* endpoint'lerinin yanıt yapısıyla birebir eşleşir.

/// Bir zaman penceresi için lokal uyum skoru.
class TimeWindowScore {
  final String window;      // morning | noon | evening
  final String label;       // Sabah | Öğle | Akşam
  final int planned;
  final int taken;
  final double localScore;  // 0.0 – 1.0
  final int consecutiveSkips;

  const TimeWindowScore({
    required this.window,
    required this.label,
    required this.planned,
    required this.taken,
    required this.localScore,
    required this.consecutiveSkips,
  });

  factory TimeWindowScore.fromJson(Map<String, dynamic> json) => TimeWindowScore(
        window: json['window'] as String,
        label: json['label'] as String,
        planned: json['planned'] as int,
        taken: json['taken'] as int,
        localScore: (json['local_score'] as num).toDouble(),
        consecutiveSkips: json['consecutive_skips'] as int,
      );

  double get scorePercent => localScore * 100;

  bool get hasData => planned > 0;
}

/// Kullanıcının YZ tarafından belirlenen davranış profili.
class BehaviorProfile {
  final String profileType;   // Sabah Tipi | Akşam Tipi | Düzenli Kullanıcı | ...
  final String profileIcon;   // emoji
  final String description;
  final double overallScore;  // 0.0 – 1.0
  final List<TimeWindowScore> windowScores;

  const BehaviorProfile({
    required this.profileType,
    required this.profileIcon,
    required this.description,
    required this.overallScore,
    required this.windowScores,
  });

  factory BehaviorProfile.fromJson(Map<String, dynamic> json) => BehaviorProfile(
        profileType: json['profile_type'] as String,
        profileIcon: json['profile_icon'] as String,
        description: json['description'] as String,
        overallScore: (json['overall_score'] as num).toDouble(),
        windowScores: (json['window_scores'] as List<dynamic>)
            .map((e) => TimeWindowScore.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  double get overallPercent => overallScore * 100;
}

/// Bir YZ müdahale kararı.
class AIDecision {
  final int id;
  final int? medicationId;
  final String? medicationName;
  final String decisionType;    // SCHEDULE_SHIFT | TONE_ADAPT | DOCTOR_REFERRAL | GAMIFICATION | LOGISTIC_REMINDER
  final String? timeWindow;     // morning | noon | evening | all
  final String explanation;     // XAI doğal dil açıklaması
  final Map<String, dynamic>? payload;
  final String status;          // PENDING | APPROVED | REJECTED | EXPIRED
  final String? outcome;        // SUCCESS | FAILURE | null
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const AIDecision({
    required this.id,
    this.medicationId,
    this.medicationName,
    required this.decisionType,
    this.timeWindow,
    required this.explanation,
    this.payload,
    required this.status,
    this.outcome,
    required this.createdAt,
    this.resolvedAt,
  });

  factory AIDecision.fromJson(Map<String, dynamic> json) => AIDecision(
        id: json['id'] as int,
        medicationId: json['medication_id'] as int?,
        medicationName: json['medication_name'] as String?,
        decisionType: json['decision_type'] as String,
        timeWindow: json['time_window'] as String?,
        explanation: json['explanation'] as String,
        payload: json['payload'] as Map<String, dynamic>?,
        status: json['status'] as String,
        outcome: json['outcome'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        resolvedAt: json['resolved_at'] != null
            ? DateTime.parse(json['resolved_at'] as String)
            : null,
      );

  bool get isPending   => status == 'PENDING';
  bool get isApproved  => status == 'APPROVED';
  bool get isRejected  => status == 'REJECTED';
  bool get isExpired   => status == 'EXPIRED';
  bool get isSuccess   => outcome == 'SUCCESS';
  bool get isFailure   => outcome == 'FAILURE';

  /// Karar tipine göre Türkçe başlık.
  String get typeLabel {
    switch (decisionType) {
      case 'SCHEDULE_SHIFT':
        return 'Adaptif Zamanlama';
      case 'TONE_ADAPT':
        // alarm_boost: "Uyuyordum" sebebinden tetiklenen güçlü alarm modu
        if (payload?['mode'] == 'alarm_boost') return 'Güçlü Alarm Modu';
        return 'Alarm Tonu Adaptasyonu';
      case 'DOCTOR_REFERRAL':
        return 'Klinik Uyarı';
      case 'GAMIFICATION':
        return 'Motivasyon Programı';
      case 'LOGISTIC_REMINDER':
        return 'Lojistik Hatırlatma';
      default:
        return 'Akıllı Öneri';
    }
  }

  /// Zaman penceresinin Türkçe adı.
  String get windowLabel {
    switch (timeWindow) {
      case 'morning': return 'Sabah';
      case 'noon':    return 'Öğle';
      case 'evening': return 'Akşam';
      default:        return 'Genel';
    }
  }
}

/// Modül 8 ana profil yanıtı.
class AIProfile {
  final BehaviorProfile behaviorProfile;
  final List<AIDecision> pendingDecisions;
  final List<AIDecision> recentDecisions;

  const AIProfile({
    required this.behaviorProfile,
    required this.pendingDecisions,
    required this.recentDecisions,
  });

  factory AIProfile.fromJson(Map<String, dynamic> json) => AIProfile(
        behaviorProfile: BehaviorProfile.fromJson(
            json['behavior_profile'] as Map<String, dynamic>),
        pendingDecisions: (json['pending_decisions'] as List<dynamic>)
            .map((e) => AIDecision.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentDecisions: (json['recent_decisions'] as List<dynamic>)
            .map((e) => AIDecision.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get hasPendingDecisions => pendingDecisions.isNotEmpty;
}
