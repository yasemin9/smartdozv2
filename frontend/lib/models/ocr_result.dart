// SmartDoz — Modül 4: OCR Sonuç Modeli
//
// Backend POST /ocr/scan endpoint'inin yanıtına karşılık gelir.
// Her OCRMatchCandidate, Algoritma 3 (Levenshtein) ile hesaplanmış
// bir ilaç adı + benzerlik skoru çiftini temsil eder.

/// Algoritma 3 — Levenshtein sonucu: tek bir aday eşleşme.
class OcrMatchCandidate {
  /// global_medications tablosundan gelen orijinal ürün adı.
  final String medicationName;

  /// Levenshtein benzerlik oranı [0.0, 1.0].
  /// 1.0 = tam eşleşme, 0.85 = minimum kabul edilen eşik.
  final double similarity;

  const OcrMatchCandidate({
    required this.medicationName,
    required this.similarity,
  });

  factory OcrMatchCandidate.fromJson(Map<String, dynamic> json) {
    return OcrMatchCandidate(
      medicationName: json['medication_name'] as String,
      similarity: (json['similarity'] as num).toDouble(),
    );
  }

  /// Benzerlik yüzde olarak gösterilmek için (ör. "92%")
  String get similarityPercent => '${(similarity * 100).round()}%';
}

/// POST /ocr/scan yanıtı.
class OcrScanResult {
  /// OCR motorundan gelen ham metin (temizlenmiş).
  final String ocrRawText;

  /// Levenshtein ≥ %85 olan adaylar, azalan benzerlik sırasında.
  /// Boş liste: OCR metin bulamadı veya eşik geçen ilaç yok.
  final List<OcrMatchCandidate> candidates;

  const OcrScanResult({
    required this.ocrRawText,
    required this.candidates,
  });

  factory OcrScanResult.fromJson(Map<String, dynamic> json) {
    final candidateList = (json['candidates'] as List<dynamic>)
        .map((e) => OcrMatchCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
    return OcrScanResult(
      ocrRawText: json['ocr_raw_text'] as String,
      candidates: candidateList,
    );
  }

  bool get hasMatches => candidates.isNotEmpty;
}
