import '../models/player_progress.dart';
import 'category_service.dart';
import 'coin_service.dart';
import 'progress_service.dart';
import 'puzzle_service.dart';

/// Tek bir başarım tanımı. Immutable, Equatable'a ihtiyaç duymayan basit
/// değer tipi — id ile karşılaştırma yapılır.
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.rewardCoins,
    required this.icon,
  });

  /// Benzersiz başarım kimliği (ör. "cat_movies_10").
  final String id;

  /// Başarımın görünen adı (ör. "Filmler Uzmanı").
  final String name;

  /// Kısa açıklama (ör. "Filmler kategorisinde 10 puzzle çöz").
  final String description;

  /// Açıldığında verilen jeton.
  final int rewardCoins;

  /// Emoji ikon.
  final String icon;
}

/// Başarım sistemi — kategori bazlı ilerleme başarımları ve global ustalık
/// başarımı. Tanımları categoryService'ten dinamik üretir; kullanıcı
/// progress'ine bakıp koşulu karşılananları `unlockedAchievements` kümesine
/// ekler ve coin ödülünü verir.
class AchievementService {
  AchievementService({
    required CategoryService categoryService,
    required PuzzleService puzzleService,
    required ProgressService progressService,
    required CoinService coinService,
  })  : _categoryService = categoryService,
        _puzzleService = puzzleService,
        _progressService = progressService,
        _coinService = coinService;

  final CategoryService _categoryService;
  final PuzzleService _puzzleService;
  final ProgressService _progressService;
  final CoinService _coinService;

  /// Kategori başına "10 çözüm" eşiği.
  static const int _tenThreshold = 10;

  /// Kategori başına 10 çözüm ödülü.
  static const int _catTenReward = 100;

  /// Kategori başına tüm puzzle'lar ödülü.
  static const int _catAllReward = 200;

  /// Master başarım ödülü.
  static const int _masterReward = 200;

  /// Master başarım id'si.
  static const String masterId = 'master_10_each';

  List<Achievement>? _cache;

  /// Tüm tanımlı başarımları döndürür. İlk çağrıda categoryService'ten
  /// kategorileri okuyup dinamik üretir.
  Future<List<Achievement>> allAchievements() async {
    if (_cache != null) {
      return _cache!;
    }
    final List<dynamic> categories = await _categoryService.loadAll();
    final List<Achievement> result = <Achievement>[];
    for (final dynamic c in categories) {
      // PuzzleCategory tipinde; runtime'da id/name/icon alanlarına erişeceğiz.
      final String id = (c as dynamic).id as String;
      final String name = (c as dynamic).name as String;
      final String icon = (c as dynamic).icon as String;
      result.add(
        Achievement(
          id: 'cat_${id}_10',
          name: '$name Uzmanı',
          description: '$name kategorisinde 10 puzzle çöz',
          rewardCoins: _catTenReward,
          icon: icon,
        ),
      );
      result.add(
        Achievement(
          id: 'cat_${id}_all',
          name: '$name Efsanesi',
          description: '$name kategorisinin tüm puzzle\'larını çöz',
          rewardCoins: _catAllReward,
          icon: icon,
        ),
      );
    }
    result.add(
      const Achievement(
        id: masterId,
        name: 'Çok Yönlü Usta',
        description: 'Tüm kategorilerin her birinde en az 10 puzzle çöz',
        rewardCoins: _masterReward,
        icon: '🏆',
      ),
    );
    _cache = List<Achievement>.unmodifiable(result);
    return _cache!;
  }

  /// Bir başarımın ilerlemesini "mevcut / hedef" olarak döndürür. Tamamlananlar
  /// için mevcut = hedef olur.
  Future<({int current, int target})> progressFor(Achievement a) async {
    final PlayerProgress progress = await _progressService.load();

    if (a.id == masterId) {
      final List<dynamic> cats = await _categoryService.loadAll();
      int done = 0;
      for (final dynamic c in cats) {
        final String cid = (c as dynamic).id as String;
        if (progress.solvedCountFor(cid) >= _tenThreshold) {
          done++;
        }
      }
      return (current: done, target: cats.length);
    }

    // Kategori bazlı başarımlar — id formatı: cat_{categoryId}_10 veya
    // cat_{categoryId}_all
    if (a.id.startsWith('cat_')) {
      final String rest = a.id.substring(4); // "{categoryId}_10" | "..._all"
      final int lastUnderscore = rest.lastIndexOf('_');
      if (lastUnderscore == -1) {
        return (current: 0, target: 1);
      }
      final String categoryId = rest.substring(0, lastUnderscore);
      final String kind = rest.substring(lastUnderscore + 1);
      final int solved = progress.solvedCountFor(categoryId);
      if (kind == '10') {
        final int target = _tenThreshold;
        final int capped = solved > target ? target : solved;
        return (current: capped, target: target);
      }
      if (kind == 'all') {
        final int total = await _puzzleService.totalCount(categoryId);
        final int capped = solved > total ? total : solved;
        return (current: capped, target: total);
      }
    }

    return (current: 0, target: 1);
  }

  /// Mevcut progress'e bakıp koşulu karşılanmış ama henüz açılmamış
  /// başarımları açar, jeton ödülünü verir ve yeni açılanların listesini
  /// döndürür.
  Future<List<Achievement>> checkAndGrant() async {
    final List<Achievement> defs = await allAchievements();
    final PlayerProgress progress = await _progressService.load();

    final List<Achievement> newlyUnlocked = <Achievement>[];

    for (final Achievement a in defs) {
      if (progress.isAchievementUnlocked(a.id)) {
        continue;
      }
      final bool satisfied = await _isSatisfied(a);
      if (!satisfied) {
        continue;
      }
      // Açık olarak işaretle + jetonu ekle.
      await _progressService.unlockAchievement(a.id);
      await _coinService.addCoins(a.rewardCoins);
      newlyUnlocked.add(a);
    }
    return newlyUnlocked;
  }

  Future<bool> _isSatisfied(Achievement a) async {
    final ({int current, int target}) p = await progressFor(a);
    return p.target > 0 && p.current >= p.target;
  }
}
