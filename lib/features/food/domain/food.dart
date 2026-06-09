/// Master food catalogue row.
///
/// All nutrient values are stored per `servingQty servingUnit` (e.g. per 100 g,
/// per 1 scoop). The repo computes "logged amount" totals by scaling.
class Food {
  final String id;
  final String? userId;          // null = global / OFF cache
  final String source;           // 'off' | 'custom' | 'recipe'
  final String? offBarcode;
  final String name;
  final String? brand;
  final double servingQty;
  final String servingUnit;
  final Nutrients per;           // macros + micros, per serving above
  final bool isFavorite;

  const Food({
    required this.id,
    required this.userId,
    required this.source,
    required this.offBarcode,
    required this.name,
    required this.brand,
    required this.servingQty,
    required this.servingUnit,
    required this.per,
    required this.isFavorite,
  });

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        id: j['id'] as String,
        userId: j['user_id'] as String?,
        source: j['source'] as String? ?? 'custom',
        offBarcode: j['off_barcode'] as String?,
        name: j['name'] as String,
        brand: j['brand'] as String?,
        servingQty: (j['serving_qty'] as num?)?.toDouble() ?? 100,
        servingUnit: j['serving_unit'] as String? ?? 'g',
        per: Nutrients.fromColumns(j),
        isFavorite: j['is_favorite'] as bool? ?? false,
      );

  Map<String, dynamic> toInsert() => {
        'user_id': userId,
        'source': source,
        if (offBarcode != null) 'off_barcode': offBarcode,
        'name': name,
        if (brand != null) 'brand': brand,
        'serving_qty': servingQty,
        'serving_unit': servingUnit,
        ...per.toColumns(),
        'is_favorite': isFavorite,
      };

  String get displayLine =>
      brand == null || brand!.isEmpty ? name : '$brand · $name';
}

/// 24-nutrient struct. Zero is the absent-value sentinel.
class Nutrients {
  final double kcal;
  final double proteinG, carbsG, fatG;
  final double fiberG, sugarG, satFatG, transFatG;
  final double cholesterolMg, sodiumMg, potassiumMg;
  final double calciumMg, ironMg, magnesiumMg, zincMg;
  final double vitAUg, vitCMg, vitDUg, vitEMg, vitKUg;
  final double b6Mg, b12Ug, folateUg;

  const Nutrients({
    this.kcal = 0,
    this.proteinG = 0, this.carbsG = 0, this.fatG = 0,
    this.fiberG = 0, this.sugarG = 0, this.satFatG = 0, this.transFatG = 0,
    this.cholesterolMg = 0, this.sodiumMg = 0, this.potassiumMg = 0,
    this.calciumMg = 0, this.ironMg = 0, this.magnesiumMg = 0, this.zincMg = 0,
    this.vitAUg = 0, this.vitCMg = 0, this.vitDUg = 0, this.vitEMg = 0, this.vitKUg = 0,
    this.b6Mg = 0, this.b12Ug = 0, this.folateUg = 0,
  });

  static const zero = Nutrients();

  /// Build from a `foods`-table row (flat columns).
  factory Nutrients.fromColumns(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return Nutrients(
      kcal: n('kcal'),
      proteinG: n('protein_g'), carbsG: n('carbs_g'), fatG: n('fat_g'),
      fiberG: n('fiber_g'), sugarG: n('sugar_g'),
      satFatG: n('sat_fat_g'), transFatG: n('trans_fat_g'),
      cholesterolMg: n('cholesterol_mg'),
      sodiumMg: n('sodium_mg'), potassiumMg: n('potassium_mg'),
      calciumMg: n('calcium_mg'), ironMg: n('iron_mg'),
      magnesiumMg: n('magnesium_mg'), zincMg: n('zinc_mg'),
      vitAUg: n('vit_a_ug'), vitCMg: n('vit_c_mg'),
      vitDUg: n('vit_d_ug'), vitEMg: n('vit_e_mg'), vitKUg: n('vit_k_ug'),
      b6Mg: n('b6_mg'), b12Ug: n('b12_ug'), folateUg: n('folate_ug'),
    );
  }

  /// Build from a jsonb micros blob on a food_log row.
  factory Nutrients.fromMicrosJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return Nutrients(
      // kcal/macros come from explicit log columns, not from micros jsonb
      fiberG: n('fiber_g'), sugarG: n('sugar_g'),
      satFatG: n('sat_fat_g'), transFatG: n('trans_fat_g'),
      cholesterolMg: n('cholesterol_mg'),
      sodiumMg: n('sodium_mg'), potassiumMg: n('potassium_mg'),
      calciumMg: n('calcium_mg'), ironMg: n('iron_mg'),
      magnesiumMg: n('magnesium_mg'), zincMg: n('zinc_mg'),
      vitAUg: n('vit_a_ug'), vitCMg: n('vit_c_mg'),
      vitDUg: n('vit_d_ug'), vitEMg: n('vit_e_mg'), vitKUg: n('vit_k_ug'),
      b6Mg: n('b6_mg'), b12Ug: n('b12_ug'), folateUg: n('folate_ug'),
    );
  }

  Map<String, dynamic> toColumns() => {
        'kcal': kcal,
        'protein_g': proteinG, 'carbs_g': carbsG, 'fat_g': fatG,
        'fiber_g': fiberG, 'sugar_g': sugarG,
        'sat_fat_g': satFatG, 'trans_fat_g': transFatG,
        'cholesterol_mg': cholesterolMg,
        'sodium_mg': sodiumMg, 'potassium_mg': potassiumMg,
        'calcium_mg': calciumMg, 'iron_mg': ironMg,
        'magnesium_mg': magnesiumMg, 'zinc_mg': zincMg,
        'vit_a_ug': vitAUg, 'vit_c_mg': vitCMg,
        'vit_d_ug': vitDUg, 'vit_e_mg': vitEMg, 'vit_k_ug': vitKUg,
        'b6_mg': b6Mg, 'b12_ug': b12Ug, 'folate_ug': folateUg,
      };

  /// Just the non-macro micros — for the `micros` jsonb on food_logs.
  Map<String, dynamic> toMicrosJson() => {
        'fiber_g': fiberG, 'sugar_g': sugarG,
        'sat_fat_g': satFatG, 'trans_fat_g': transFatG,
        'cholesterol_mg': cholesterolMg,
        'sodium_mg': sodiumMg, 'potassium_mg': potassiumMg,
        'calcium_mg': calciumMg, 'iron_mg': ironMg,
        'magnesium_mg': magnesiumMg, 'zinc_mg': zincMg,
        'vit_a_ug': vitAUg, 'vit_c_mg': vitCMg,
        'vit_d_ug': vitDUg, 'vit_e_mg': vitEMg, 'vit_k_ug': vitKUg,
        'b6_mg': b6Mg, 'b12_ug': b12Ug, 'folate_ug': folateUg,
      };

  Nutrients scale(double f) => Nutrients(
        kcal: kcal * f,
        proteinG: proteinG * f, carbsG: carbsG * f, fatG: fatG * f,
        fiberG: fiberG * f, sugarG: sugarG * f,
        satFatG: satFatG * f, transFatG: transFatG * f,
        cholesterolMg: cholesterolMg * f,
        sodiumMg: sodiumMg * f, potassiumMg: potassiumMg * f,
        calciumMg: calciumMg * f, ironMg: ironMg * f,
        magnesiumMg: magnesiumMg * f, zincMg: zincMg * f,
        vitAUg: vitAUg * f, vitCMg: vitCMg * f,
        vitDUg: vitDUg * f, vitEMg: vitEMg * f, vitKUg: vitKUg * f,
        b6Mg: b6Mg * f, b12Ug: b12Ug * f, folateUg: folateUg * f,
      );

  Nutrients operator +(Nutrients o) => Nutrients(
        kcal: kcal + o.kcal,
        proteinG: proteinG + o.proteinG, carbsG: carbsG + o.carbsG, fatG: fatG + o.fatG,
        fiberG: fiberG + o.fiberG, sugarG: sugarG + o.sugarG,
        satFatG: satFatG + o.satFatG, transFatG: transFatG + o.transFatG,
        cholesterolMg: cholesterolMg + o.cholesterolMg,
        sodiumMg: sodiumMg + o.sodiumMg, potassiumMg: potassiumMg + o.potassiumMg,
        calciumMg: calciumMg + o.calciumMg, ironMg: ironMg + o.ironMg,
        magnesiumMg: magnesiumMg + o.magnesiumMg, zincMg: zincMg + o.zincMg,
        vitAUg: vitAUg + o.vitAUg, vitCMg: vitCMg + o.vitCMg,
        vitDUg: vitDUg + o.vitDUg, vitEMg: vitEMg + o.vitEMg, vitKUg: vitKUg + o.vitKUg,
        b6Mg: b6Mg + o.b6Mg, b12Ug: b12Ug + o.b12Ug, folateUg: folateUg + o.folateUg,
      );
}
