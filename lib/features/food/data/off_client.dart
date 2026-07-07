import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/food.dart';

/// Open Food Facts API client.
///
/// No key required. We use the v2 search API (cgi/search.pl) for text and
/// the v0 product API for barcodes. All nutrient values are normalised to
/// per-100 g (`servingQty=100, servingUnit='g'`).
class OffClient {
  static const _ua = 'Atlas/1.0 (personal-OS; contact: shrujalsrinath@gmail.com)';
  final http.Client _http;
  OffClient({http.Client? client}) : _http = client ?? http.Client();

  /// Free-text search. Returns up to [limit] hits, filtered and ranked by
  /// relevance to the original query.
  Future<List<Food>> search(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) return const [];
    final q = query.trim().toLowerCase();

    // Fetch more than we need so we can filter aggressively.
    final fetchSize = (limit * 3).clamp(25, 80);
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl'
      '?search_terms=${Uri.encodeQueryComponent(query)}'
      '&search_simple=1&action=process&json=1'
      '&page_size=$fetchSize'
      '&fields=code,product_name,brands,nutriments,serving_size,serving_quantity',
    );
    try {
      final r = await _http.get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return const [];
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final products = (body['products'] as List?) ?? const [];

      final parsed = products
          .whereType<Map<String, dynamic>>()
          .map(_productToFood)
          .whereType<Food>()
          .toList();

      // Filter: product name must actually contain a query word.
      final queryWords = q.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
      final filtered = parsed.where((f) {
        final name = f.name.toLowerCase();
        // At least one query word must appear in the name
        return queryWords.any((w) => name.contains(w));
      }).toList();

      // Score and sort by relevance.
      filtered.sort((a, b) => _relevance(b, q).compareTo(_relevance(a, q)));

      return filtered.take(limit).toList(growable: false);
    } catch (e, s) {
      if (kDebugMode) debugPrint('OFF search error: $e\n$s');
      return const [];
    }
  }

  /// Relevance score: higher = more relevant to the query.
  double _relevance(Food f, String query) {
    final name = f.name.toLowerCase();
    double score = 0;

    // Exact name match
    if (name == query) {
      score += 100;
    }
    // Name starts with query
    else if (name.startsWith(query)) {
      score += 80;
    }
    // Name contains query as a standalone word
    else if (RegExp('\\b${RegExp.escape(query)}\\b').hasMatch(name)) {
      score += 60;
    }
    // Name contains query as substring
    else if (name.contains(query)) {
      score += 40;
    }
    // Fallback: partial word matches
    else {
      score += 20;
    }

    // Boost: has real calorie data (not 0)
    if (f.per.kcal > 0) score += 15;

    // Boost: has protein data (likely a real food, not just a drink)
    if (f.per.proteinG > 0) score += 5;

    // Penalize very long names (processed/branded items)
    if (f.name.length > 60) score -= 10;
    if (f.name.length > 100) score -= 10;

    // Penalize names with too many commas (ingredient-style names)
    final commas = ','.allMatches(f.name).length;
    if (commas > 2) score -= commas * 3;

    // Boost shorter, simpler names (likely whole foods)
    if (f.name.length <= 30) score += 8;

    // Slight boost if brand is null/empty (generic/whole food)
    if (f.brand == null || f.brand!.isEmpty) score += 5;

    return score;
  }

  /// Lookup by barcode.
  Future<Food?> byBarcode(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;
    // Encode the scanned value so it can't break out of the URL path.
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v0/product/${Uri.encodeComponent(clean)}.json',
    );
    try {
      final r = await _http.get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null;
      return _productToFood(body['product'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Food? _productToFood(Map<String, dynamic> p) {
    final name = (p['product_name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    final n = (p['nutriments'] as Map<String, dynamic>?) ?? const {};
    double v(String key) => (n[key] as num?)?.toDouble() ?? 0;

    final per = Nutrients(
      // OFF reports per-100g values keyed `<nutrient>_100g`.
      kcal: v('energy-kcal_100g'),
      proteinG: v('proteins_100g'),
      carbsG: v('carbohydrates_100g'),
      fatG: v('fat_100g'),
      fiberG: v('fiber_100g'),
      sugarG: v('sugars_100g'),
      satFatG: v('saturated-fat_100g'),
      transFatG: v('trans-fat_100g'),
      cholesterolMg: v('cholesterol_100g') * 1000, // OFF gives g; convert to mg
      sodiumMg: v('sodium_100g') * 1000,
      potassiumMg: v('potassium_100g') * 1000,
      calciumMg: v('calcium_100g') * 1000,
      ironMg: v('iron_100g') * 1000,
      magnesiumMg: v('magnesium_100g') * 1000,
      zincMg: v('zinc_100g') * 1000,
      vitAUg: v('vitamin-a_100g') * 1e6,         // OFF gives g; convert to µg
      vitCMg: v('vitamin-c_100g') * 1000,
      vitDUg: v('vitamin-d_100g') * 1e6,
      vitEMg: v('vitamin-e_100g') * 1000,
      vitKUg: v('vitamin-k_100g') * 1e6,
      b6Mg: v('vitamin-b6_100g') * 1000,
      b12Ug: v('vitamin-b12_100g') * 1e6,
      folateUg: v('vitamin-b9_100g') * 1e6,
    );

    final brand = (p['brands'] as String?)?.split(',').first.trim();

    // Packaged items should default to their package serving, not a generic
    // "Bowl". OFF carries `serving_quantity` (usually grams) for most products;
    // fall back to a 50 g pack so a scanned snack still reads "1 Pack", never
    // "1 Bowl (200 g)". Mirrors FoodRepository._cacheBranded so the live scan
    // and the cached row agree.
    final servRaw = p['serving_quantity'];
    final servQ = servRaw is num
        ? servRaw.toDouble()
        : double.tryParse(servRaw?.toString() ?? '');
    final measures = <FoodMeasure>[
      const FoodMeasure('g', 1),
      if (servQ != null && servQ > 1 && servQ < 2000)
        FoodMeasure('Serving', servQ)
      else
        const FoodMeasure('Pack', 50),
    ];

    return Food(
      id: 'off:${p['code']}',
      userId: null,
      source: 'off',
      offBarcode: p['code'] as String?,
      name: name,
      brand: brand?.isEmpty == true ? null : brand,
      servingQty: 100,
      servingUnit: 'g',
      per: per,
      measures: measures,
      isFavorite: false,
    );
  }
}
