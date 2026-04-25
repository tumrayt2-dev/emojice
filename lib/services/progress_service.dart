import 'package:hive_flutter/hive_flutter.dart';

import '../models/player_progress.dart';

/// Oyuncu ilerlemesini Hive üzerinden saklayan servis.
///
/// Hive box tam tipli olmak yerine dinamik (`Box`) olarak açılır; içeride
/// sadece birkaç JSON uyumlu alan tutulur. Bu sayede custom adapter
/// gerekmez ve release modda sürüm uyumsuzluğu yaşanmaz.
class ProgressService {
  ProgressService();

  static const String _boxName = 'player_progress_box';
  static const String _key = 'current';

  Box<dynamic>? _box;

  /// Hive kutusunu açar; [Hive.initFlutter] önceden çağrılmış olmalıdır.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      return;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  /// Mevcut ilerlemeyi döndürür. Kayıt yoksa başlangıç değerlerini yazar.
  Future<PlayerProgress> load() async {
    await init();
    final dynamic raw = _box!.get(_key);
    if (raw == null) {
      final PlayerProgress initial = PlayerProgress.initial();
      await _persist(initial);
      return initial;
    }
    final Map<String, dynamic> json = _coerceMap(raw);
    return PlayerProgress.fromJson(json);
  }

  /// Verilen ilerlemeyi diske yazar.
  Future<void> save(PlayerProgress progress) async {
    await init();
    await _persist(progress);
  }

  /// Bir puzzle'ı çözülmüş olarak işaretler; zaten çözülmüşse aynı nesneyi
  /// döndürür.
  Future<PlayerProgress> markSolved({
    required String categoryId,
    required String puzzleId,
    int scoreGain = 0,
  }) async {
    final PlayerProgress current = await load();
    if (current.isSolved(categoryId, puzzleId)) {
      return current;
    }
    final Map<String, List<String>> updated =
        Map<String, List<String>>.from(current.solvedPuzzles);
    final List<String> list = List<String>.from(updated[categoryId] ?? const <String>[]);
    list.add(puzzleId);
    updated[categoryId] = list;

    final PlayerProgress next = current.copyWith(
      solvedPuzzles: updated,
      totalScore: current.totalScore + scoreGain,
    );
    await _persist(next);
    return next;
  }

  /// Coin ekler.
  Future<PlayerProgress> addCoins(int amount) async {
    final PlayerProgress current = await load();
    final PlayerProgress next = current.copyWith(coins: current.coins + amount);
    await _persist(next);
    return next;
  }

  /// Coin harcar. Yeterli bakiye yoksa [StateError] fırlatır.
  Future<PlayerProgress> spendCoins(int amount) async {
    final PlayerProgress current = await load();
    if (current.coins < amount) {
      throw StateError('Yetersiz coin bakiyesi');
    }
    final PlayerProgress next = current.copyWith(
      coins: current.coins - amount,
      hintsUsed: current.hintsUsed + 1,
    );
    await _persist(next);
    return next;
  }

  /// Toplam skoru ayarlar.
  Future<PlayerProgress> addScore(int amount) async {
    final PlayerProgress current = await load();
    final PlayerProgress next =
        current.copyWith(totalScore: current.totalScore + amount);
    await _persist(next);
    return next;
  }

  /// Bir puzzle için kazanılan yıldız sayısını (1..3) kaydeder. Var olan
  /// değerden küçükse korunur (daha iyi skor asla geri gitmez).
  Future<PlayerProgress> setStars({
    required String categoryId,
    required String puzzleId,
    required int stars,
  }) async {
    final int clamped = stars < 1
        ? 1
        : stars > 3
            ? 3
            : stars;
    final PlayerProgress current = await load();
    final int existing = current.starsFor(categoryId, puzzleId);
    if (existing >= clamped) {
      return current;
    }
    final Map<String, Map<String, int>> updated =
        <String, Map<String, int>>{};
    current.earnedStars.forEach((String k, Map<String, int> v) {
      updated[k] = Map<String, int>.from(v);
    });
    final Map<String, int> inner =
        Map<String, int>.from(updated[categoryId] ?? const <String, int>{});
    inner[puzzleId] = clamped;
    updated[categoryId] = inner;

    final PlayerProgress next = current.copyWith(earnedStars: updated);
    await _persist(next);
    return next;
  }

  /// Bir puzzle için kazanılan yıldız sayısını döndürür.
  Future<int> getStars({
    required String categoryId,
    required String puzzleId,
  }) async {
    final PlayerProgress current = await load();
    return current.starsFor(categoryId, puzzleId);
  }

  /// Bir başarımı "açıldı" olarak işaretler. Zaten açıksa mevcut state'i
  /// döndürür.
  Future<PlayerProgress> unlockAchievement(String id) async {
    final PlayerProgress current = await load();
    if (current.isAchievementUnlocked(id)) {
      return current;
    }
    final Set<String> updated = <String>{...current.unlockedAchievements, id};
    final PlayerProgress next = current.copyWith(unlockedAchievements: updated);
    await _persist(next);
    return next;
  }

  /// Bir kategori için reklam sayacını 1 artırır (her +5 Bulmaca Puanı).
  /// `lastUnlockAdAt` saatlik limit hesabı için güncellenir.
  Future<PlayerProgress> incrementUnlockAd(String categoryId) async {
    final PlayerProgress current = await load();
    final Map<String, int> updated =
        Map<String, int>.from(current.categoryUnlockAds);
    updated[categoryId] = (updated[categoryId] ?? 0) + 1;
    final PlayerProgress next = current.copyWith(
      categoryUnlockAds: updated,
      lastUnlockAdAt: DateTime.now().toUtc(),
    );
    await _persist(next);
    return next;
  }

  /// Paketli kullanıcı saatte 1 tier-açma reklamı izleyebilir. Limit etkin
  /// mi (henüz 1 saat geçmedi mi) ve kalan süre saniye olarak döner.
  /// `noAdsActive` false ise limit yok (paketsiz kullanıcı serbest).
  Future<({bool blocked, Duration remaining})> tierAdCooldown({
    required bool noAdsActive,
  }) async {
    if (!noAdsActive) {
      return (blocked: false, remaining: Duration.zero);
    }
    final PlayerProgress current = await load();
    final DateTime? last = current.lastUnlockAdAt;
    if (last == null) {
      return (blocked: false, remaining: Duration.zero);
    }
    final Duration elapsed = DateTime.now().toUtc().difference(last);
    if (elapsed >= const Duration(hours: 1)) {
      return (blocked: false, remaining: Duration.zero);
    }
    return (blocked: true, remaining: const Duration(hours: 1) - elapsed);
  }

  /// Tüm ilerlemeyi sıfırlar.
  Future<PlayerProgress> reset() async {
    final PlayerProgress initial = PlayerProgress.initial();
    await _persist(initial);
    return initial;
  }

  /// Dev modu için: Bulmaca Puanı'na verilen kadar puan ekler. Internal
  /// olarak `__dev_boost__` kategori sayacına `points/5` reklam izlenmiş
  /// gibi yazılır; UnlockService.totalAdPoints toplamı bunu kapsar.
  Future<PlayerProgress> devAddPoints(int points) async {
    final int adsToAdd = points ~/ 5;
    if (adsToAdd <= 0) {
      return load();
    }
    final PlayerProgress current = await load();
    final Map<String, int> updated =
        Map<String, int>.from(current.categoryUnlockAds);
    const String devKey = '__dev_boost__';
    updated[devKey] = (updated[devKey] ?? 0) + adsToAdd;
    final PlayerProgress next = current.copyWith(categoryUnlockAds: updated);
    await _persist(next);
    return next;
  }

  Future<void> _persist(PlayerProgress progress) async {
    await _box!.put(_key, progress.toJson());
  }

  /// Hive'dan dönen `Map<dynamic, dynamic>`'i güvenli şekilde
  /// `Map<String, dynamic>`'e çevirir.
  Map<String, dynamic> _coerceMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    final Map<dynamic, dynamic> m = raw as Map<dynamic, dynamic>;
    final Map<String, dynamic> out = <String, dynamic>{};
    m.forEach((dynamic key, dynamic value) {
      out[key.toString()] = _coerceValue(value);
    });
    return out;
  }

  dynamic _coerceValue(dynamic value) {
    if (value is Map) {
      final Map<String, dynamic> out = <String, dynamic>{};
      value.forEach((dynamic k, dynamic v) {
        out[k.toString()] = _coerceValue(v);
      });
      return out;
    }
    if (value is List) {
      return value.map<dynamic>(_coerceValue).toList();
    }
    return value;
  }
}
