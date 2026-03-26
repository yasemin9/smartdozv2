// SmartDoz - Modül 8: Metin Tabanlı Akıllı İpucu Modeli
//
// Backend GET /ai/tips yanıtıyla birebir eşleşir.
// Sistem hiçbir otomatik eylem yapmaz; yalnızca metin önerisi sunar.

/// Modül 8 — Akıllı ipucu kartı.
///
/// [tipType] değerleri:
///   - REASON_BASED    : Kullanıcının belirttiği atlama sebebine göre
///   - ADHERENCE_BASED : Genel uyum skoruna göre
class SmartTip {
  final String tipId;      // YAN_ETKI | UYKU | UNUTMA | LOJISTIK | STOK | ETKILESIM | ISTEKSIZLIK | DUSUK_UYUM | GENEL
  final String icon;       // emoji
  final String title;      // Kısa başlık
  final String message;    // Kullanıcıya gösterilecek öneri metni
  final String xaiReason;  // XAI: neden bu ipucu üretildi
  final String tipType;    // REASON_BASED | ADHERENCE_BASED

  const SmartTip({
    required this.tipId,
    required this.icon,
    required this.title,
    required this.message,
    required this.xaiReason,
    required this.tipType,
  });

  factory SmartTip.fromJson(Map<String, dynamic> json) => SmartTip(
        tipId: json['tip_id'] as String,
        icon: json['icon'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        xaiReason: json['xai_reason'] as String,
        tipType: json['tip_type'] as String,
      );

  bool get isReasonBased    => tipType == 'REASON_BASED';
  bool get isAdherenceBased => tipType == 'ADHERENCE_BASED';
  bool get isPositive       => tipId == 'GENEL';
  bool get isUrgent         => tipId == 'YAN_ETKI' || tipId == 'ETKILESIM';
}
