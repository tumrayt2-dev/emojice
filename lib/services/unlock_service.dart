import 'dart:math' as math;

import '../models/category.dart';
import '../models/player_progress.dart';

/// Bir reklamın kazandırdığı Bulmaca Puanı.
const int kAdPuzzlePoints = 5;

/// Bir kategori için hesaplanmış kilit durumu.
class UnlockStatus {
  const UnlockStatus({
    required this.isUnlocked,
    required this.reason,
    required this.unlockedByAds,
    required this.tierProgress,
    required this.tierTarget,
    required this.effectiveProgress,
    this.chainProgress,
    this.chainTarget,
    this.chainCategoryName,
    required this.adsWatched,
    required this.adsRemaining,
  });

  /// Kategori açık mı?
  final bool isUnlocked;

  /// Kullanıcıya gösterilecek kısa açıklama (kilitse şart, değilse boş).
  final String reason;

  /// Reklam sayesinde mi açılmış?
  final bool unlockedByAds;

  /// Mevcut çözüm sayısı (saf bulmaca).
  final int tierProgress;

  /// Tier hedefi.
  final int tierTarget;

  /// Reklam puanı dahil efektif Bulmaca Puanı.
  final int effectiveProgress;

  /// Zincir kategorideki mevcut çözüm (varsa).
  final int? chainProgress;

  /// Zincir kategorideki hedef (varsa).
  final int? chainTarget;

  /// Zincir kategorisinin görünen adı (varsa).
  final String? chainCategoryName;

  /// Bu kategori için izlenen reklam sayısı.
  final int adsWatched;

  /// Reklamla açma için kalan reklam sayısı (0 ise reklam yetiyor).
  final int adsRemaining;
}

/// Kategori kilit mantığını tek yerde toplayan servis.
/// Saf fonksiyonel — I/O yapmaz, pür hesap döner.
///
/// Formül:
///   effectiveProgress = totalSolvedCount + (adsWatched * 5)
///   tierOk = effectiveProgress >= tierValue
///   adsRemaining = ceil(max(0, tierValue - effectiveProgress) / 5)
class UnlockService {
  const UnlockService();

  /// Bir kategori için kilit durumunu hesaplar.
  UnlockStatus statusFor({
    required PuzzleCategory category,
    required PlayerProgress progress,
    required List<PuzzleCategory> allCategories,
  }) {
    final UnlockRequirement? req = category.unlock;
    if (req == null || req.type == UnlockType.none) {
      return const UnlockStatus(
        isUnlocked: true,
        reason: '',
        unlockedByAds: false,
        tierProgress: 0,
        tierTarget: 0,
        effectiveProgress: 0,
        adsWatched: 0,
        adsRemaining: 0,
      );
    }

    final int totalSolved = progress.totalSolvedCount;
    // Reklam puanı GLOBAL'dir — bir kategori için izlenen reklam tüm
    // tier'a eklenir, böylece aynı tier'daki diğer kategoriler de açılır.
    final int totalAdPoints = progress.totalAdPoints;
    final int adsWatched = progress.unlockAdsFor(category.id);
    final int effective = totalSolved + totalAdPoints;

    // Tier şartı (efektif puana göre).
    final bool tierOk = effective >= req.tierValue;

    // Zincir şartı (varsa). Reklam puanı zincire EKLENMEZ — zincir
    // kategorinin gerçek çözümü gerekir.
    bool chainOk = true;
    int? chainProgress;
    int? chainTarget;
    String? chainName;
    if (req.type == UnlockType.chain &&
        req.chainTarget != null &&
        req.chainValue != null) {
      chainProgress = progress.solvedCountFor(req.chainTarget!);
      chainTarget = req.chainValue;
      chainName = _nameOf(req.chainTarget!, allCategories);
      chainOk = chainProgress >= req.chainValue!;
    }

    final bool isUnlocked = tierOk && chainOk;
    final bool unlockedByAds = isUnlocked && totalSolved < req.tierValue;

    final int tierGap = req.tierValue - effective;
    final int adsRemaining = tierGap > 0
        ? (tierGap + kAdPuzzlePoints - 1) ~/ kAdPuzzlePoints
        : 0;

    String reason = '';
    if (!isUnlocked) {
      if (!tierOk) {
        final int remaining = math.max(0, req.tierValue - effective);
        reason = '$remaining Bulmaca Puanı daha gerekli';
        if (req.type == UnlockType.chain && chainTarget != null) {
          final String chainLabel = chainName ?? req.chainTarget!;
          reason +=
              ' · $chainLabel: ${chainProgress ?? 0}/$chainTarget çözüm';
        }
      } else if (!chainOk && chainTarget != null) {
        final int remaining = chainTarget - (chainProgress ?? 0);
        final String chainLabel = chainName ?? req.chainTarget!;
        reason = '$chainLabel kategorisinden $remaining bulmaca daha çöz';
      }
    }

    return UnlockStatus(
      isUnlocked: isUnlocked,
      reason: reason,
      unlockedByAds: unlockedByAds,
      tierProgress: totalSolved,
      tierTarget: req.tierValue,
      effectiveProgress: effective,
      chainProgress: chainProgress,
      chainTarget: chainTarget,
      chainCategoryName: chainName,
      adsWatched: adsWatched,
      adsRemaining: adsRemaining,
    );
  }

  /// Açık kategori id'lerini döndürür.
  Set<String> unlockedIds({
    required List<PuzzleCategory> categories,
    required PlayerProgress progress,
  }) {
    return <String>{
      for (final PuzzleCategory c in categories)
        if (statusFor(
          category: c,
          progress: progress,
          allCategories: categories,
        ).isUnlocked)
          c.id,
    };
  }

  String? _nameOf(String id, List<PuzzleCategory> all) {
    for (final PuzzleCategory c in all) {
      if (c.id == id) {
        return c.name;
      }
    }
    return null;
  }
}
