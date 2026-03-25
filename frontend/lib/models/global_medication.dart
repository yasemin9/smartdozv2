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
  final String? category2;
  final String? category3;
  final String? category4;
  final String? category5;
  final String? description;

  const GlobalMedication({
    required this.id,
    required this.productName,
    this.activeIngredient,
    this.atcCode,
    this.barcode,
    this.category1,
    this.category2,
    this.category3,
    this.category4,
    this.category5,
    this.description,
  });

  factory GlobalMedication.fromJson(Map<String, dynamic> json) {
    return GlobalMedication(
      id: json['id'] as int,
      productName: json['product_name'] as String,
      activeIngredient: json['active_ingredient'] as String?,
      atcCode: json['atc_code'] as String?,
      barcode: json['barcode'] as String?,
      category1: json['category_1'] as String?,
      category2: json['category_2'] as String?,
      category3: json['category_3'] as String?,
      category4: json['category_4'] as String?,
      category5: json['category_5'] as String?,
      description: json['description'] as String?,
    );
  }

  @override
  String toString() => productName;
}
