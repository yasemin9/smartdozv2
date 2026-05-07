/// Barkod tarama yanıtı modeli
/// Backend: POST /barcode/scan endpoint'inin yanıtına karşılık gelir.

class BarcodeMatchResult {
  final bool found;
  final String barcode;
  final int? medicationId;
  final String? medicationName;
  final double confidence;
  final String message;

  BarcodeMatchResult({
    required this.found,
    required this.barcode,
    required this.medicationId,
    required this.medicationName,
    required this.confidence,
    required this.message,
  });

  factory BarcodeMatchResult.fromJson(Map<String, dynamic> json) {
    return BarcodeMatchResult(
      found: json['found'] as bool? ?? false,
      barcode: json['barcode'] as String? ?? '',
      medicationId: json['medication_id'] as int?,
      medicationName: json['medication_name'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'found': found,
      'barcode': barcode,
      'medication_id': medicationId,
      'medication_name': medicationName,
      'confidence': confidence,
      'message': message,
    };
  }

  @override
  String toString() =>
      'BarcodeMatchResult(found: $found, barcode: $barcode, '
      'medicationName: $medicationName, confidence: $confidence, '
      'message: $message)';
}
