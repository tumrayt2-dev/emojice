import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/category.dart';
import 'puzzle_service.dart';

/// `assets/data/categories.json` dosyasını okuyan ve kategori ile ilgili
/// yardımcı sorguları sağlayan servis.
class CategoryService {
  CategoryService({PuzzleService? puzzleService})
      : _puzzleService = puzzleService ?? PuzzleService();

  static const String _assetPath = 'assets/data/categories.json';

  final PuzzleService _puzzleService;
  List<PuzzleCategory>? _cache;

  /// Kategorileri yükler. Her kategori için gerçek puzzle sayısını
  /// `PuzzleService` üzerinden hesaplar.
  Future<List<PuzzleCategory>> loadAll() async {
    if (_cache != null) {
      return _cache!;
    }
    final String raw = await rootBundle.loadString(_assetPath);
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;

    final List<PuzzleCategory> result = <PuzzleCategory>[];
    for (final dynamic entry in list) {
      final Map<String, dynamic> json = entry as Map<String, dynamic>;
      final String id = json['id'] as String;
      final int count = await _puzzleService.totalCount(id);
      final Map<String, dynamic>? unlockJson =
          json['unlock'] as Map<String, dynamic>?;
      result.add(
        PuzzleCategory(
          id: id,
          name: json['name'] as String,
          icon: json['icon'] as String,
          puzzleCount: count,
          isPremium: json['isPremium'] as bool? ?? false,
          unlock: unlockJson != null
              ? UnlockRequirement.fromJson(unlockJson)
              : null,
        ),
      );
    }
    _cache = List<PuzzleCategory>.unmodifiable(result);
    return _cache!;
  }

  /// Belirli bir kategorinin premium olup olmadığını döndürür.
  Future<bool> isPremium(String categoryId) async {
    final List<PuzzleCategory> all = await loadAll();
    for (final PuzzleCategory c in all) {
      if (c.id == categoryId) {
        return c.isPremium;
      }
    }
    return false;
  }

  /// Bir kategorideki ilerleme yüzdesi (0.0 - 1.0).
  Future<double> progressRatio(String categoryId, int solvedCount) async {
    final int total = await _puzzleService.totalCount(categoryId);
    if (total <= 0) {
      return 0;
    }
    final double ratio = solvedCount / total;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  /// Önbelleği temizler.
  void clearCache() {
    _cache = null;
  }
}
