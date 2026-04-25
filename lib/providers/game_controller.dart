import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_state.dart';
import '../models/hint_type.dart';
import '../models/player_progress.dart';
import '../models/puzzle.dart';
import '../models/category.dart';
import '../services/achievement_service.dart';
import '../services/category_service.dart';
import '../services/coin_service.dart';
import '../services/letter_service.dart';
import '../services/progress_service.dart';
import '../services/puzzle_service.dart';
import '../services/unlock_service.dart';
import 'service_providers.dart';

/// Oyun mantığını yöneten Riverpod StateNotifier.
class GameController extends StateNotifier<GameState> {
  GameController({
    required PuzzleService puzzleService,
    required CategoryService categoryService,
    required ProgressService progressService,
    required CoinService coinService,
    required LetterService letterService,
    required AchievementService achievementService,
    required UnlockService unlockService,
    Random? random,
  })  : _puzzleService = puzzleService,
        _categoryService = categoryService,
        _progressService = progressService,
        _coinService = coinService,
        _letterService = letterService,
        _achievementService = achievementService,
        _unlockService = unlockService,
        _random = random ?? Random(),
        super(GameState.idle());

  final PuzzleService _puzzleService;
  final CategoryService _categoryService;
  final ProgressService _progressService;
  final CoinService _coinService;
  final LetterService _letterService;
  final AchievementService _achievementService;
  final UnlockService _unlockService;
  final Random _random;

  /// Karışık mod için sabit categoryId. Bu değer verildiğinde tüm
  /// kategorilerdeki puzzle havuzu kullanılır ve progress takibi yine
  /// puzzle'ın kendi [Puzzle.categoryId] değeri üzerinden yapılır.
  static const String mixCategoryId = '__mix__';

  /// Verilen kategorideki belirli bir soruyu yükler ve state'i hazırlar.
  ///
  /// [puzzleId] null verilirse o kategorideki henüz çözülmemiş ilk soru
  /// yüklenir; hepsi çözülmüşse listenin ilk sorusu kullanılır.
  ///
  /// [categoryId] değeri [mixCategoryId] (`'__mix__'`) ise karışık mod
  /// devreye girer: puzzle havuzu tüm kategorilerden gelir; [puzzleId]
  /// varsa o soru yüklenir, yoksa çözülmemişlerden (yoksa tümünden)
  /// rastgele bir soru seçilir. State'te `currentCategoryId` değeri
  /// karışık modda da `'__mix__'` olarak korunur.
  Future<void> loadPuzzle({
    required String categoryId,
    String? puzzleId,
  }) async {
    final bool isMix = categoryId == mixCategoryId;
    List<Puzzle> puzzles = isMix
        ? await _puzzleService.loadAll()
        : await _puzzleService.byCategory(categoryId);
    if (isMix) {
      // Karışık mod: sadece oyuncuya açık kategorilerin puzzle'ları
      // görünür. Fazla içerik (gelecekte kategori kapasitesi aşıldığında)
      // da bu havuzda değerlendirilir.
      final List<PuzzleCategory> categories = await _categoryService.loadAll();
      final PlayerProgress progress = await _progressService.load();
      final Set<String> unlocked = _unlockService.unlockedIds(
        categories: categories,
        progress: progress,
      );
      puzzles = <Puzzle>[
        for (final Puzzle p in puzzles)
          if (unlocked.contains(p.categoryId)) p,
      ];
    }
    if (puzzles.isEmpty) {
      state = GameState.idle().copyWith(currentCategoryId: categoryId);
      return;
    }

    Puzzle? target;
    if (puzzleId != null) {
      for (final Puzzle p in puzzles) {
        if (p.id == puzzleId) {
          target = p;
          break;
        }
      }
    }
    if (target == null) {
      final PlayerProgress progress = await _progressService.load();
      if (isMix) {
        final List<Puzzle> unsolved = <Puzzle>[
          for (final Puzzle p in puzzles)
            if (!progress.isSolved(p.categoryId, p.id)) p,
        ];
        if (unsolved.isNotEmpty) {
          target = unsolved[_random.nextInt(unsolved.length)];
        } else {
          target = puzzles[_random.nextInt(puzzles.length)];
        }
      } else {
        for (final Puzzle p in puzzles) {
          if (!progress.isSolved(categoryId, p.id)) {
            target = p;
            break;
          }
        }
        target ??= puzzles.first;
      }
    }

    final int coins = await _coinService.getCoins();
    final List<String> pool = _letterService.buildLetterPool(target.answer);
    final List<LetterTile> tiles = <LetterTile>[
      for (int i = 0; i < pool.length; i++)
        LetterTile(
          letter: pool[i],
          isUsed: false,
          isEliminated: false,
          originalIndex: i,
        ),
    ];
    final int slots = _letterService.lettersOfAnswer(target.answer).length;

    state = GameState(
      currentPuzzle: target,
      selectedLetters: List<String?>.filled(slots, null),
      availableLetters: tiles,
      gameStatus: GameStatus.playing,
      currentCategoryId: categoryId,
      hintsUsed: 0,
      score: 0,
      coins: coins,
      isRepeatSolve: false,
      newlyUnlockedAchievements: const <Achievement>[],
      revealedSlotIndices: const <int>{},
    );
  }

  /// Alttaki bir harfe tıklanınca üstteki ilk boş kutuya yerleştirir.
  void selectLetter(int index) {
    if (state.gameStatus != GameStatus.playing) {
      return;
    }
    if (index < 0 || index >= state.availableLetters.length) {
      return;
    }
    final LetterTile tile = state.availableLetters[index];
    if (tile.isUsed || tile.isEliminated) {
      return;
    }

    final int emptySlot = state.selectedLetters.indexWhere((String? s) => s == null);
    if (emptySlot == -1) {
      return;
    }

    final List<String?> newSelected = List<String?>.from(state.selectedLetters);
    newSelected[emptySlot] = tile.letter;

    final List<LetterTile> newTiles = List<LetterTile>.from(state.availableLetters);
    newTiles[index] = tile.copyWith(isUsed: true);

    state = state.copyWith(
      selectedLetters: newSelected,
      availableLetters: newTiles,
    );

    _maybeCheckAnswer();
  }

  /// Üstteki bir kutucuğa tıklanınca harfi geri alır.
  void removeLetter(int slotIndex) {
    if (state.gameStatus != GameStatus.playing &&
        state.gameStatus != GameStatus.failed) {
      return;
    }
    if (slotIndex < 0 || slotIndex >= state.selectedLetters.length) {
      return;
    }
    // İpucu ile yerleştirilmiş slot kullanıcı eli ile alınamaz.
    if (state.revealedSlotIndices.contains(slotIndex)) {
      return;
    }
    final String? letter = state.selectedLetters[slotIndex];
    if (letter == null) {
      return;
    }

    final List<String?> newSelected = List<String?>.from(state.selectedLetters);
    newSelected[slotIndex] = null;

    // Kullanılan ilk eşleşen harfi tekrar aktif yap.
    final List<LetterTile> newTiles = List<LetterTile>.from(state.availableLetters);
    for (int i = 0; i < newTiles.length; i++) {
      final LetterTile t = newTiles[i];
      if (t.isUsed && !t.isEliminated && t.letter == letter) {
        newTiles[i] = t.copyWith(isUsed: false);
        break;
      }
    }

    state = state.copyWith(
      selectedLetters: newSelected,
      availableLetters: newTiles,
      gameStatus: GameStatus.playing,
    );
  }

  /// Kutucuklar tamamen doluysa otomatik kontrol eder.
  void _maybeCheckAnswer() {
    final bool allFilled =
        state.selectedLetters.every((String? s) => s != null && s.isNotEmpty);
    if (!allFilled) {
      return;
    }
    // Micro-delay yerine senkron kontrol; UI animasyonu ayrıca tetikleyecek.
    checkAnswer();
  }

  /// Harfleri birleştirip cevapla karşılaştırır.
  Future<void> checkAnswer() async {
    final Puzzle? puzzle = state.currentPuzzle;
    if (puzzle == null) {
      return;
    }
    final List<String> correct = _letterService.lettersOfAnswer(puzzle.answer);
    if (state.selectedLetters.length != correct.length) {
      return;
    }
    bool isCorrect = true;
    for (int i = 0; i < correct.length; i++) {
      if (state.selectedLetters[i] != correct[i]) {
        isCorrect = false;
        break;
      }
    }

    if (isCorrect) {
      // Farm koruma: aynı puzzle daha önce çözüldüyse ödül verme.
      final PlayerProgress existing = await _progressService.load();
      final bool alreadySolved =
          existing.isSolved(puzzle.categoryId, puzzle.id);

      if (alreadySolved) {
        state = state.copyWith(
          gameStatus: GameStatus.solved,
          score: 0,
          coins: state.coins,
          isRepeatSolve: true,
          newlyUnlockedAchievements: const <Achievement>[],
        );
        return;
      }

      final int gained = _calculateScore(puzzle.difficulty);
      await _progressService.markSolved(
        categoryId: puzzle.categoryId,
        puzzleId: puzzle.id,
        scoreGain: gained,
      );
      // Yıldız hesabı: 0 ipucu → 3, 1 ipucu → 2, 2+ ipucu → 1.
      final int stars = state.hintsUsed == 0
          ? 3
          : state.hintsUsed == 1
              ? 2
              : 1;
      await _progressService.setStars(
        categoryId: puzzle.categoryId,
        puzzleId: puzzle.id,
        stars: stars,
      );
      final int newCoins = await _coinService.rewardCorrectAnswer();

      // Başarım kontrolü — açılanlar varsa coin ödülü burada eklenmiş olur.
      final List<Achievement> unlocked =
          await _achievementService.checkAndGrant();

      // Achievement ödülleri coin bakiyesini değiştirmiş olabilir — son
      // bakiyeyi yeniden oku.
      final int finalCoins = unlocked.isEmpty
          ? newCoins
          : await _coinService.getCoins();

      state = state.copyWith(
        gameStatus: GameStatus.solved,
        score: gained,
        coins: finalCoins,
        isRepeatSolve: false,
        newlyUnlockedAchievements: unlocked,
      );
    } else {
      // Yanlış → failed state (UI shake animasyonu için).
      // UI animasyon sonunda [resetPuzzle] çağıracak.
      state = state.copyWith(gameStatus: GameStatus.failed);
    }
  }

  /// Seçilmiş harfleri temizler, havuzdaki karoları tekrar aktifleştirir.
  /// "Harf aç" ipucu ile yerleştirilmiş slot'lar (revealedSlotIndices)
  /// SIFIRLANMAZ — kullanıcı para vererek aldığı ipucu korunur.
  void _resetSelection() {
    final Set<int> revealed = state.revealedSlotIndices;
    final List<String?> oldSelected = state.selectedLetters;

    // Slot temizliği: revealed olanları koru.
    final List<String?> cleared = <String?>[
      for (int i = 0; i < oldSelected.length; i++)
        revealed.contains(i) ? oldSelected[i] : null,
    ];

    // Karoları aktif yap. Revealed slot için yerleşmiş tile'ı isUsed=true tut.
    // Bunu yapmak için: revealed tile'larının harfini say, havuzda o
    // miktarda isUsed=true bırak; geri kalanını aktif et.
    final Map<String, int> revealedNeeds = <String, int>{};
    for (final int idx in revealed) {
      final String? l = oldSelected[idx];
      if (l != null) {
        revealedNeeds[l] = (revealedNeeds[l] ?? 0) + 1;
      }
    }

    final List<LetterTile> newTiles = <LetterTile>[];
    for (final LetterTile t in state.availableLetters) {
      if (t.isEliminated) {
        newTiles.add(t);
        continue;
      }
      final int remaining = revealedNeeds[t.letter] ?? 0;
      if (remaining > 0) {
        // Bu tile revealed slot'a ait — used olarak kalsın.
        newTiles.add(t.copyWith(isUsed: true));
        revealedNeeds[t.letter] = remaining - 1;
      } else {
        newTiles.add(t.copyWith(isUsed: false));
      }
    }

    state = state.copyWith(
      selectedLetters: cleared,
      availableLetters: newTiles,
      gameStatus: GameStatus.playing,
    );
  }

  /// Çözülmüş bir puzzle yeniden açıldığında slotları doğru cevapla
  /// önden doldurur. Havuzdaki karoları sırayla `isUsed=true` yaparak
  /// tüketir. Çağrıldıktan sonra state `solved` olmaz — sadece görsel
  /// bir önizleme sağlar; `GameStatus.playing` korunur ki kullanıcı
  /// harfleri kaldırıp tekrar oynayabilsin.
  void prefillSolution() {
    final Puzzle? puzzle = state.currentPuzzle;
    if (puzzle == null) {
      return;
    }
    final List<String> correct = _letterService.lettersOfAnswer(puzzle.answer);
    if (state.selectedLetters.length != correct.length) {
      return;
    }

    final List<LetterTile> newTiles = <LetterTile>[
      for (final LetterTile t in state.availableLetters)
        t.copyWith(isUsed: false),
    ];
    final List<String?> newSelected = List<String?>.filled(correct.length, null);

    for (int slot = 0; slot < correct.length; slot++) {
      final String needed = correct[slot];
      int? tileIndex;
      for (int i = 0; i < newTiles.length; i++) {
        final LetterTile t = newTiles[i];
        if (!t.isUsed && !t.isEliminated && t.letter == needed) {
          tileIndex = i;
          break;
        }
      }
      if (tileIndex == null) {
        // Cevabı tam dolduramıyorsak önizlemeyi iptal et.
        return;
      }
      newTiles[tileIndex] = newTiles[tileIndex].copyWith(isUsed: true);
      newSelected[slot] = needed;
    }

    state = state.copyWith(
      selectedLetters: newSelected,
      availableLetters: newTiles,
      gameStatus: GameStatus.playing,
    );
  }

  /// Mevcut soruyu sıfırlar (harfler geri, ipuçları sayacı korunur).
  void resetPuzzle() {
    if (state.currentPuzzle == null) {
      return;
    }
    _resetSelection();
  }

  /// İpucu kullanır. Başarıyla kullanılırsa `true` döner; coin yetmiyorsa
  /// `false` döner (UI reklam izleme teklifi gösterebilir).
  Future<bool> useHint(HintType type) async {
    if (state.gameStatus != GameStatus.playing) {
      return false;
    }
    final Puzzle? puzzle = state.currentPuzzle;
    if (puzzle == null) {
      return false;
    }
    final int? newCoins = await _coinService.spend(type.cost);
    if (newCoins == null) {
      return false;
    }

    switch (type) {
      case HintType.revealLetter:
        _applyRevealLetter(puzzle);
        break;
      case HintType.eliminateLetters:
        _applyEliminateLetters(puzzle);
        break;
    }

    state = state.copyWith(
      coins: newCoins,
      hintsUsed: state.hintsUsed + 1,
    );

    // Harf açıldıysa cevap tamamlanmış olabilir.
    _maybeCheckAnswer();
    return true;
  }

  void _applyRevealLetter(Puzzle puzzle) {
    final List<String> correct = _letterService.lettersOfAnswer(puzzle.answer);
    final List<int> emptySlots = <int>[];
    for (int i = 0; i < state.selectedLetters.length; i++) {
      if (state.selectedLetters[i] == null) {
        emptySlots.add(i);
      }
    }
    if (emptySlots.isEmpty) {
      return;
    }
    final int targetSlot = emptySlots[_random.nextInt(emptySlots.length)];
    final String needed = correct[targetSlot];

    // Havuzdan bu harfe karşılık gelen ilk kullanılmamış/elenmemiş karoyu bul.
    final List<LetterTile> newTiles = List<LetterTile>.from(state.availableLetters);
    int? tileIndex;
    for (int i = 0; i < newTiles.length; i++) {
      final LetterTile t = newTiles[i];
      if (!t.isUsed && !t.isEliminated && t.letter == needed) {
        tileIndex = i;
        break;
      }
    }

    // Eğer havuzda yoksa (ör. zaten kullanılmış ama yanlış yere konmuş),
    // kullanılmış olanlardan birini "geri alıp" doğru yere yerleştirelim.
    if (tileIndex == null) {
      for (int i = 0; i < newTiles.length; i++) {
        final LetterTile t = newTiles[i];
        if (t.isUsed && !t.isEliminated && t.letter == needed) {
          tileIndex = i;
          break;
        }
      }
    }

    if (tileIndex == null) {
      return;
    }

    final List<String?> newSelected = List<String?>.from(state.selectedLetters);
    // Bu harf zaten yanlış bir slotta ise onu kaldır.
    for (int i = 0; i < newSelected.length; i++) {
      if (newSelected[i] == needed && i != targetSlot) {
        // Sadece ilk eşleşen slot serbest bırakılır.
        if (correct[i] != needed) {
          newSelected[i] = null;
          break;
        }
      }
    }
    newSelected[targetSlot] = needed;
    newTiles[tileIndex] = newTiles[tileIndex].copyWith(isUsed: true);

    // Bu slot ipucu ile dolduruldu — yanlış cevapta sıfırlanmasın.
    final Set<int> revealed = <int>{
      ...state.revealedSlotIndices,
      targetSlot,
    };

    state = state.copyWith(
      selectedLetters: newSelected,
      availableLetters: newTiles,
      revealedSlotIndices: revealed,
    );
  }

  void _applyEliminateLetters(Puzzle puzzle) {
    final List<String> correct = _letterService.lettersOfAnswer(puzzle.answer);
    // Doğru harflerin sayımını çıkar — kaç adet bu harfin geçtiğini bilmemiz
    // gerek ki fazlası "yanlış" sayılabilsin.
    final Map<String, int> needed = <String, int>{};
    for (final String c in correct) {
      needed[c] = (needed[c] ?? 0) + 1;
    }
    // Havuzdaki her harfin kaç kopyası olduğunu takip et.
    // "Gereğinden fazla" olan kopyalar yanlış adaydır.
    final Map<String, int> usedCount = <String, int>{};
    final List<int> wrongCandidates = <int>[];
    for (int i = 0; i < state.availableLetters.length; i++) {
      final LetterTile t = state.availableLetters[i];
      if (t.isEliminated || t.isUsed) {
        continue;
      }
      final int already = usedCount[t.letter] ?? 0;
      final int max = needed[t.letter] ?? 0;
      if (already >= max) {
        wrongCandidates.add(i);
      } else {
        usedCount[t.letter] = already + 1;
      }
    }
    wrongCandidates.shuffle(_random);

    final List<LetterTile> newTiles = List<LetterTile>.from(state.availableLetters);
    final int eliminateCount = wrongCandidates.length < 3 ? wrongCandidates.length : 3;
    for (int k = 0; k < eliminateCount; k++) {
      final int idx = wrongCandidates[k];
      newTiles[idx] = newTiles[idx].copyWith(isEliminated: true);
    }

    state = state.copyWith(availableLetters: newTiles);
  }

  /// Kategorideki sıradaki soruya geçer (mevcut sorudan sonra gelen ilk soru).
  Future<void> nextPuzzle() async {
    final Puzzle? current = state.currentPuzzle;
    final String categoryId =
        current?.categoryId ?? state.currentCategoryId;
    if (categoryId.isEmpty) {
      return;
    }
    final List<Puzzle> puzzles = await _puzzleService.byCategory(categoryId);
    if (puzzles.isEmpty) {
      return;
    }
    String? nextId;
    if (current != null) {
      final int idx = puzzles.indexWhere((Puzzle p) => p.id == current.id);
      if (idx != -1 && idx + 1 < puzzles.length) {
        nextId = puzzles[idx + 1].id;
      }
    }
    await loadPuzzle(categoryId: categoryId, puzzleId: nextId);
  }

  /// Coin bakiyesini dışarıdan günceller (ör. reklam ödülü sonrası).
  void syncCoins(int newCoins) {
    state = state.copyWith(coins: newCoins);
  }

  /// UI, dialog'u gösterdikten sonra yeni açılan başarım listesini temizler
  /// ki tekrar tekrar gösterilmesin.
  void consumeNewlyUnlockedAchievements() {
    if (state.newlyUnlockedAchievements.isEmpty) {
      return;
    }
    state = state.copyWith(
      newlyUnlockedAchievements: const <Achievement>[],
    );
  }

  /// Puan hesaplama kuralı — sabit, zorluğa bağlı.
  /// difficulty 1 → 20, 2 → 40, 3 → 60. Diğer değerler için minimum 5.
  int _calculateScore(int difficulty) {
    switch (difficulty) {
      case 1:
        return 20;
      case 2:
        return 40;
      case 3:
        return 60;
      default:
        return 5;
    }
  }
}

/// Oyun controller provider'ı.
final StateNotifierProvider<GameController, GameState> gameControllerProvider =
    StateNotifierProvider<GameController, GameState>((Ref ref) {
  return GameController(
    puzzleService: ref.watch(puzzleServiceProvider),
    categoryService: ref.watch(categoryServiceProvider),
    progressService: ref.watch(progressServiceProvider),
    coinService: ref.watch(coinServiceProvider),
    letterService: ref.watch(letterServiceProvider),
    achievementService: ref.watch(achievementServiceProvider),
    unlockService: ref.watch(unlockServiceProvider),
  );
});
