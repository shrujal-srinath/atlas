/// In-memory inverted index over the bundled Indian foods catalog.
///
/// Loaded once on first use from `assets/food_db/in_foods.json`. Search is
/// tokenized (word-level) with priority: exact-prefix > whole-token > prefix >
/// substring > alias match. Sub-50ms on typical queries; no network.
///
/// The bundled dataset is hand-curated common Indian foods using standard
/// per-100g reference nutrition values. Source-of-truth IDs are stable
/// (`local-{slug}`) so logs can reference these foods later.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../domain/food.dart';

class _Entry {
  final Food food;
  final List<String> tokens;     // all searchable tokens (name + aliases + category)
  final List<String> nameTokens; // name-only tokens (for higher score)
  final String typicalPortionLabel;
  final double typicalPortionG;
  const _Entry({
    required this.food,
    required this.tokens,
    required this.nameTokens,
    required this.typicalPortionLabel,
    required this.typicalPortionG,
  });
}

class LocalFoodIndex {
  LocalFoodIndex._();
  static final LocalFoodIndex instance = LocalFoodIndex._();

  Future<List<_Entry>>? _loading;
  List<_Entry>? _entries;
  // word → indices in _entries
  final Map<String, List<int>> _byToken = {};

  Future<void> _ensureLoaded() async {
    if (_entries != null) return;
    _loading ??= _load();
    _entries = await _loading;
  }

  Future<List<_Entry>> _load() async {
    final raw = await rootBundle.loadString('assets/food_db/in_foods.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final out = <_Entry>[];
    for (final row in list) {
      final name = (row['name'] as String).trim();
      final aliases = (row['aliases'] as List? ?? const [])
          .whereType<String>()
          .map((s) => s.trim())
          .toList();
      final category = (row['category'] as String? ?? '').trim();
      final nameTokens = _tokenize(name);
      final allTokens = <String>{...nameTokens};
      for (final a in aliases) {
        allTokens.addAll(_tokenize(a));
      }
      if (category.isNotEmpty) allTokens.addAll(_tokenize(category));

      final food = Food(
        id: 'local-${_slugify(name)}',
        userId: null,
        source: 'local',
        offBarcode: null,
        name: name,
        brand: 'Indian',
        servingQty: 100,
        servingUnit: 'g',
        per: Nutrients(
          kcal: (row['kcal'] as num? ?? 0).toDouble(),
          proteinG: (row['proteinG'] as num? ?? 0).toDouble(),
          carbsG: (row['carbsG'] as num? ?? 0).toDouble(),
          fatG: (row['fatG'] as num? ?? 0).toDouble(),
          fiberG: (row['fiberG'] as num? ?? 0).toDouble(),
        ),
        isFavorite: false,
      );
      out.add(_Entry(
        food: food,
        tokens: allTokens.toList(),
        nameTokens: nameTokens,
        typicalPortionLabel: row['typicalPortionLabel'] as String? ?? '',
        typicalPortionG: (row['typicalPortionG'] as num? ?? 100).toDouble(),
      ));
    }

    // Build inverted index.
    _byToken.clear();
    for (int i = 0; i < out.length; i++) {
      for (final t in out[i].tokens) {
        _byToken.putIfAbsent(t, () => []).add(i);
      }
    }
    return out;
  }

  static List<String> _tokenize(String s) {
    return s
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String _slugify(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Search the bundled catalog. Returns top [limit] hits ordered by relevance.
  Future<List<Food>> search(String query, {int limit = 20}) async {
    await _ensureLoaded();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final terms = _tokenize(q);
    if (terms.isEmpty) return const [];

    // Score each entry hit by union of term matches.
    final scores = <int, double>{};
    for (final term in terms) {
      // 1) exact token match — best.
      final exact = _byToken[term];
      if (exact != null) {
        for (final i in exact) {
          scores[i] = (scores[i] ?? 0) + 10;
        }
      }
      // 2) token starts-with — strong.
      for (final entry in _byToken.entries) {
        if (entry.key == term) continue; // already scored above
        if (entry.key.startsWith(term)) {
          for (final i in entry.value) {
            scores[i] = (scores[i] ?? 0) + 5;
          }
        } else if (entry.key.contains(term) && term.length >= 3) {
          // 3) token contains (looser; requires 3+ chars to avoid noise).
          for (final i in entry.value) {
            scores[i] = (scores[i] ?? 0) + 1;
          }
        }
      }
    }

    if (scores.isEmpty) return const [];

    // Name-token boost: if any matched token is in nameTokens, bump.
    for (final idx in scores.keys.toList()) {
      final e = _entries![idx];
      for (final term in terms) {
        if (e.nameTokens.any((t) => t == term)) {
          scores[idx] = scores[idx]! + 8;
        } else if (e.nameTokens.any((t) => t.startsWith(term))) {
          scores[idx] = scores[idx]! + 3;
        }
      }
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted.take(limit)) _entries![e.key].food,
    ];
  }

  /// Returns the "typical portion" hint for a known catalog food (or null).
  /// UI uses this to show "1 katori ≈ 150 g" under search results.
  Future<({double grams, String label})?> typicalPortionFor(String foodId) async {
    await _ensureLoaded();
    final e = _entries!.firstWhere(
      (e) => e.food.id == foodId,
      orElse: () => _entries!.first,
    );
    if (e.food.id != foodId) return null;
    if (e.typicalPortionLabel.isEmpty) return null;
    return (grams: e.typicalPortionG, label: e.typicalPortionLabel);
  }
}
