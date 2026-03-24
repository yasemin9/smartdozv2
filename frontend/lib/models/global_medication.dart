/// SmartDoz - Global İlaç Kataloğu Modeli
///
/// Global ilaç veritabanından (global_medications tablosu) dönen kayıtları temsil eder.
/// Modül 1 TypeAhead araması ve Modül 3 ilaç etkileşim kontrolü için kullanılır.
class GlobalMedication {
  final int id;
  final String productName;
  final String? activeIngredient;
  final String? atcCode;
  final String? barcode;
  final String? category1;

  const GlobalMedication({
    required this.id,
    required this.productName,
    this.activeIngredient,
    this.atcCode,
    this.barcode,
    this.category1,
  });

  factory GlobalMedication.fromJson(Map<String, dynamic> json) {
    return GlobalMedication(
      id: json['id'] as int,
      productName: json['product_name'] as String,
      activeIngredient: json['active_ingredient'] as String?,
      atcCode: json['atc_code'] as String?,
      barcode: json['barcode'] as String?,
      category1: json['category_1'] as String?,
    );
  }

  @override
  String toString() => productName;
}
