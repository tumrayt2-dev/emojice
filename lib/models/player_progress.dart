import 'package:equatable/equatable.dart';

/// Veri formatı sürümü. Kategori yeniden yapılanması (movies → foreign_movies,
/// series → turkish_series + foreign_series) sonrasında eski puzzle id'leri
/// geçersiz kaldı. Eski (v1) kayıtlardan yüklenirken `solvedPuzzles` ve
/// `earnedStars` SIFIRLANIR ve sürüm v2'ye yükseltilir. Coin/başarımlar
/// korunur — kullanıcı oyunu sıfırdan başlar gibi olmaz, ekonomi sürer.
const int kCurrentDataVersion = 2;

/// Oyuncunun ilerleme ve ekonomi durumu.
class PlayerProgress extends Equatable {
  const PlayerProgress({
    required this.solvedPuzzles,
    required this.earnedStars,
    required this.totalScore,
    required this.coins,
    required this.hintsUsed,
    required this.unlockedAchievements,
    required this.categoryUnlockAds,
    required this.lastUnlockAdAt,
    required this.dataVersion,
  });

  /// Her kategoride çözülmüş puzzle id'leri.
  final Map<String, List<String>> solvedPuzzles;

  /// Her kategoride kazanılan yıldız sayısı (categoryId → puzzleId → 1..3).
  final Map<String, Map<String, int>> earnedStars;

  /// Toplam puan.
  final int totalScore;

  /// İpuçları için harcanabilir coin bakiyesi.
  final int coins;

  /// Toplam kullanılmış ipucu sayısı.
  final int hintsUsed;

  /// Açılmış başarım id'leri kümesi.
  final Set<String> unlockedAchievements;

  /// Kategori bazında reklam izleyerek açma için biriktirilen sayaçlar.
  /// Anahtar: categoryId, değer: izlenen reklam sayısı.
  final Map<String, int> categoryUnlockAds;

  /// En son tier-açma reklamı izlenen zaman (paketli kullanıcı saatlik
  /// limit hesabı için). null → hiç izlenmemiş.
  final DateTime? lastUnlockAdAt;

  /// Yüklenen kayıt formatının sürümü.
  final int dataVersion;

  /// Başlangıç değerleri.
  factory PlayerProgress.initial() {
    return const PlayerProgress(
      solvedPuzzles: <String, List<String>>{},
      earnedStars: <String, Map<String, int>>{},
      totalScore: 0,
      coins: 100,
      hintsUsed: 0,
      unlockedAchievements: <String>{},
      categoryUnlockAds: <String, int>{},
      lastUnlockAdAt: null,
      dataVersion: kCurrentDataVersion,
    );
  }

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    final int storedVersion = (json['dataVersion'] as num?)?.toInt() ?? 1;
    final bool migrate = storedVersion < kCurrentDataVersion;

    Map<String, List<String>> solved;
    Map<String, Map<String, int>> stars;

    if (migrate) {
      // Kategori yeniden yapılanması nedeniyle eski puzzle id'leri geçersiz —
      // çözüm sayaçlarını ve yıldızları sıfırla. Coin, başarımlar korunur.
      solved = <String, List<String>>{};
      stars = <String, Map<String, int>>{};
    } else {
      final Map<String, dynamic> rawSolved =
          (json['solvedPuzzles'] as Map<String, dynamic>? ?? <String, dynamic>{});
      solved = rawSolved.map(
        (String key, dynamic value) => MapEntry<String, List<String>>(
          key,
          (value as List<dynamic>).map((dynamic e) => e as String).toList(),
        ),
      );

      final Map<String, dynamic> rawStars =
          (json['earnedStars'] as Map<String, dynamic>? ?? <String, dynamic>{});
      stars = rawStars.map(
        (String key, dynamic value) {
          final Map<String, dynamic> inner =
              (value as Map<String, dynamic>? ?? <String, dynamic>{});
          return MapEntry<String, Map<String, int>>(
            key,
            inner.map((String k, dynamic v) =>
                MapEntry<String, int>(k, (v as num).toInt())),
          );
        },
      );
    }

    // Geriye uyumlu: eski kayıtlarda unlockedAchievements bulunmayabilir.
    final List<dynamic> rawAchievements =
        (json['unlockedAchievements'] as List<dynamic>? ?? <dynamic>[]);
    final Set<String> achievements = <String>{
      for (final dynamic e in rawAchievements) e as String,
    };

    // Geriye uyumlu: eski kayıtlarda categoryUnlockAds bulunmayabilir.
    final Map<String, dynamic> rawAds = (json['categoryUnlockAds']
            as Map<String, dynamic>? ??
        <String, dynamic>{});
    final Map<String, int> ads = rawAds.map(
      (String k, dynamic v) => MapEntry<String, int>(k, (v as num).toInt()),
    );

    final dynamic rawAdAt = json['lastUnlockAdAt'];
    DateTime? lastAdAt;
    if (rawAdAt is String && rawAdAt.isNotEmpty) {
      lastAdAt = DateTime.tryParse(rawAdAt);
    } else if (rawAdAt is num) {
      lastAdAt =
          DateTime.fromMillisecondsSinceEpoch(rawAdAt.toInt(), isUtc: true);
    }

    return PlayerProgress(
      solvedPuzzles: solved,
      earnedStars: stars,
      totalScore: migrate ? 0 : ((json['totalScore'] as num?)?.toInt() ?? 0),
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      hintsUsed: (json['hintsUsed'] as num?)?.toInt() ?? 0,
      unlockedAchievements: achievements,
      categoryUnlockAds: ads,
      lastUnlockAdAt: lastAdAt,
      dataVersion: kCurrentDataVersion,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'solvedPuzzles': solvedPuzzles,
        'earnedStars': earnedStars.map(
          (String k, Map<String, int> v) =>
              MapEntry<String, Map<String, int>>(k, Map<String, int>.from(v)),
        ),
        'totalScore': totalScore,
        'coins': coins,
        'hintsUsed': hintsUsed,
        'unlockedAchievements': unlockedAchievements.toList(),
        'categoryUnlockAds': Map<String, int>.from(categoryUnlockAds),
        'lastUnlockAdAt': lastUnlockAdAt?.toIso8601String(),
        'dataVersion': dataVersion,
      };

  PlayerProgress copyWith({
    Map<String, List<String>>? solvedPuzzles,
    Map<String, Map<String, int>>? earnedStars,
    int? totalScore,
    int? coins,
    int? hintsUsed,
    Set<String>? unlockedAchievements,
    Map<String, int>? categoryUnlockAds,
    DateTime? lastUnlockAdAt,
    bool clearLastUnlockAdAt = false,
    int? dataVersion,
  }) {
    return PlayerProgress(
      solvedPuzzles: solvedPuzzles ?? this.solvedPuzzles,
      earnedStars: earnedStars ?? this.earnedStars,
      totalScore: totalScore ?? this.totalScore,
      coins: coins ?? this.coins,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      categoryUnlockAds: categoryUnlockAds ?? this.categoryUnlockAds,
      lastUnlockAdAt: clearLastUnlockAdAt
          ? null
          : (lastUnlockAdAt ?? this.lastUnlockAdAt),
      dataVersion: dataVersion ?? this.dataVersion,
    );
  }

  /// Bir kategorideki çözülmüş soru sayısı.
  int solvedCountFor(String categoryId) =>
      solvedPuzzles[categoryId]?.length ?? 0;

  /// Tüm kategorilerdeki toplam çözüm sayısı (Bulmaca Puanı temeli).
  int get totalSolvedCount {
    int sum = 0;
    for (final List<String> ids in solvedPuzzles.values) {
      sum += ids.length;
    }
    return sum;
  }

  /// Reklam puanı toplamı (her reklam +5 Bulmaca Puanı).
  int get totalAdPoints {
    int sum = 0;
    for (final int v in categoryUnlockAds.values) {
      sum += v * 5;
    }
    return sum;
  }

  /// Belirli bir puzzle çözülmüş mü?
  bool isSolved(String categoryId, String puzzleId) =>
      solvedPuzzles[categoryId]?.contains(puzzleId) ?? false;

  /// Belirli bir puzzle için kazanılan yıldız sayısı (yoksa 0).
  int starsFor(String categoryId, String puzzleId) =>
      earnedStars[categoryId]?[puzzleId] ?? 0;

  /// Belirli bir başarım açıldı mı?
  bool isAchievementUnlocked(String id) => unlockedAchievements.contains(id);

  /// Bir kategori için biriktirilen reklam sayısı.
  int unlockAdsFor(String categoryId) => categoryUnlockAds[categoryId] ?? 0;

  @override
  List<Object?> get props => <Object?>[
        solvedPuzzles,
        earnedStars,
        totalScore,
        coins,
        hintsUsed,
        unlockedAchievements,
        categoryUnlockAds,
        lastUnlockAdAt,
        dataVersion,
      ];
}
