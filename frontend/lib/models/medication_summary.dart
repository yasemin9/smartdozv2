/// SmartDoz - Modül 5: İlaç Özeti Modeli
///
/// Hugging Face / kural tabanlı NLP ile üretilen yapılandırılmış özet.
class MedicationSummary {
  final String productName;
  final String? activeIngredient;
  final String? atcCode;
  final String? category;

  /// Ne için kullanılır? (eski alan — geriye dönük uyumluluk)
  final String indication;

  /// Yan etkiler (eski alan)
  final String sideEffects;

  /// Dozaj / nasıl kullanılır (eski alan)
  final String dosage;

  /// Uyarılar (eski alan)
  final String warnings;

  /// NER: tespit edilen dozaj ifadeleri
  final List<String> dosageEntities;

  /// NER: kritik yan etkiler
  final List<String> criticalSideEffects;

  // ── Yeni 3-Kategori Yapılandırılmış Özet ──────────────────────────────────

  /// 🌟 Temel Faydası — ilacın ne için kullanıldığı (sade dilde)
  final List<String> temelFaydasi;

  /// 🥄 Kullanım Şekli — doz ve uygulama talimatları
  final List<String> kullanimSekli;

  /// ⚠️ Dikkat Edilecekler — uyarılar ve yan etkiler
  final List<String> dikkatEdilecekler;

  /// Özetleme yöntemi: "llm" | "transformers" | "rule_based"
  final String summaryMethod;

  /// Yapay zeka sorumluluk reddi
  final String disclaimer;

  const MedicationSummary({
    required this.productName,
    this.activeIngredient,
    this.atcCode,
    this.category,
    required this.indication,
    required this.sideEffects,
    required this.dosage,
    required this.warnings,
    this.dosageEntities = const [],
    this.criticalSideEffects = const [],
    this.temelFaydasi = const [],
    this.kullanimSekli = const [],
    this.dikkatEdilecekler = const [],
    this.summaryMethod = 'rule_based',
    this.disclaimer = '',
  });

  factory MedicationSummary.fromJson(Map<String, dynamic> json) {
    List<String> _strings(dynamic raw) =>
        (raw as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

    return MedicationSummary(
      productName: json['product_name'] as String,
      activeIngredient: json['active_ingredient'] as String?,
      atcCode: json['atc_code'] as String?,
      category: json['category'] as String?,
      indication: json['indication'] as String? ?? '',
      sideEffects: json['side_effects'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      warnings: json['warnings'] as String? ?? '',
      dosageEntities: _strings(json['dosage_entities']),
      criticalSideEffects: _strings(json['critical_side_effects']),
      temelFaydasi: _strings(json['temel_faydasi']),
      kullanimSekli: _strings(json['kullanim_sekli']),
      dikkatEdilecekler: _strings(json['dikkat_edilecekler']),
      summaryMethod: json['summary_method'] as String? ?? 'rule_based',
      disclaimer: json['disclaimer'] as String? ?? '',
    );
  }
}
