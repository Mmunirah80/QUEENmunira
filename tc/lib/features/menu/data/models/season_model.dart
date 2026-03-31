class SeasonModel {
  const SeasonModel({
    required this.name,
    required this.nameAr,
    required this.isHijri,
    required this.priceIncreasePct,
  });

  final String name;
  final String nameAr;
  final bool isHijri;
  final double priceIncreasePct;

  factory SeasonModel.fromMap(Map<String, dynamic> map) {
    return SeasonModel(
      name: (map['name'] as String? ?? '').trim(),
      nameAr: (map['name_ar'] as String? ?? '').trim(),
      isHijri: map['is_hijri'] as bool? ?? false,
      priceIncreasePct: _toDouble(map['price_increase_pct']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

