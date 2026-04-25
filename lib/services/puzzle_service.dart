import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/puzzle.dart';

/// `assets/data/puzzles.json` dosyasını okuyan ve kategoriye göre filtreleme
/// yapan servis. Tek seferlik yükleme yapar, sonrasında belleğe alınmış
/// listeyi kullanır.
class PuzzleService {
  PuzzleService();

  static const String _assetPath = 'assets/data/puzzles.json';

  List<Puzzle>? _cache;

  /// Tüm puzzle'ları döndürür; ilk çağrıda JSON'u okur.
  Future<List<Puzzle>> loadAll() async {
    if (_cache != null) {
      return _cache!;
    }
    final String raw = await rootBundle.loadString(_assetPath);
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    _cache = list
        .map((dynamic e) => Puzzle.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return _cache!;
  }

  /// Belirli bir kategorideki puzzle'ları kolaydan zora sıralayarak döndürür.
  Future<List<Puzzle>> byCategory(String categoryId) async {
    final List<Puzzle> all = await loadAll();
    final List<Puzzle> filtered = all
        .where((Puzzle p) => p.categoryId == categoryId)
        .toList(growable: false);
    filtered.sort((Puzzle a, Puzzle b) => a.difficulty.compareTo(b.difficulty));
    return filtered;
  }

  /// Belirli bir id ile puzzle getirir; yoksa `null`.
  Future<Puzzle?> byId(String puzzleId) async {
    final List<Puzzle> all = await loadAll();
    for (final Puzzle p in all) {
      if (p.id == puzzleId) {
        return p;
      }
    }
    return null;
  }

  /// Bir kategorideki toplam puzzle sayısı.
  Future<int> totalCount(String categoryId) async {
    final List<Puzzle> all = await loadAll();
    return all.where((Puzzle p) => p.categoryId == categoryId).length;
  }

  /// Önbelleği temizler (test veya hot-reload için).
  void clearCache() {
    _cache = null;
  }
}
