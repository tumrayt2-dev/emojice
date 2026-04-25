import 'package:equatable/equatable.dart';

import '../services/achievement_service.dart';
import 'puzzle.dart';

/// Oyunun anlık durumu.
enum GameStatus {
  /// Henüz bir soru yüklenmedi.
  idle,

  /// Soru yüklendi, oyuncu oynuyor.
  playing,

  /// Soru doğru çözüldü.
  solved,

  /// Yanlış tahmin sonrası kısa failed state (animasyon için).
  failed,
}

/// Alttaki seçilebilir harf havuzundaki bir karo.
class LetterTile extends Equatable {
  const LetterTile({
    required this.letter,
    required this.isUsed,
    required this.isEliminated,
    required this.originalIndex,
  });

  /// Tek büyük harf.
  final String letter;

  /// Seçilip üstteki cevap kutucuğuna yerleştirilmiş mi?
  final bool isUsed;

  /// İpucu ile elenmiş mi (yanlış harf)?
  final bool isEliminated;

  /// Karışık listedeki orijinal pozisyon (UI'da sabit konum için).
  final int originalIndex;

  LetterTile copyWith({
    String? letter,
    bool? isUsed,
    bool? isEliminated,
    int? originalIndex,
  }) {
    return LetterTile(
      letter: letter ?? this.letter,
      isUsed: isUsed ?? this.isUsed,
      isEliminated: isEliminated ?? this.isEliminated,
      originalIndex: originalIndex ?? this.originalIndex,
    );
  }

  @override
  List<Object?> get props => <Object?>[letter, isUsed, isEliminated, originalIndex];
}

/// Oyun ekranının tam state'i.
class GameState extends Equatable {
  const GameState({
    required this.currentPuzzle,
    required this.selectedLetters,
    required this.availableLetters,
    required this.gameStatus,
    required this.currentCategoryId,
    required this.hintsUsed,
    required this.score,
    required this.coins,
    required this.isRepeatSolve,
    required this.newlyUnlockedAchievements,
    required this.revealedSlotIndices,
  });

  /// Aktif bulmaca; idle durumda null.
  final Puzzle? currentPuzzle;

  /// Cevap kutucuklarındaki harfler; null = boş.
  final List<String?> selectedLetters;

  /// Alttaki seçilebilir harf karoları.
  final List<LetterTile> availableLetters;

  /// Oyun durumu.
  final GameStatus gameStatus;

  /// Şu an oynanan kategori id.
  final String currentCategoryId;

  /// Bu soruda kullanılan ipucu sayısı.
  final int hintsUsed;

  /// Bu soruda kazanılan puan (çözüldükten sonra dolu).
  final int score;

  /// Oyuncunun mevcut coin bakiyesi.
  final int coins;

  /// Son çözüm, daha önce çözülmüş bir puzzle'ın yeniden çözümü mü? Bu alan
  /// `true` ise puzzle ödül verilmeden sadece "doğru" olarak gösterilmiştir
  /// (farm koruma).
  final bool isRepeatSolve;

  /// Son `checkAnswer`'da yeni açılan başarımlar. Dialog gösterdikten sonra
  /// GameController bu listeyi boşaltır.
  final List<Achievement> newlyUnlockedAchievements;

  /// "Harf aç" ipucu ile yerleştirilmiş slot index'leri. Yanlış cevapta
  /// bu slot'lar SIFIRLANMAZ — kullanıcı para vererek aldığı ipucu
  /// korunur.
  final Set<int> revealedSlotIndices;

  /// Idle başlangıç state'i.
  factory GameState.idle() {
    return const GameState(
      currentPuzzle: null,
      selectedLetters: <String?>[],
      availableLetters: <LetterTile>[],
      gameStatus: GameStatus.idle,
      currentCategoryId: '',
      hintsUsed: 0,
      score: 0,
      coins: 0,
      isRepeatSolve: false,
      newlyUnlockedAchievements: <Achievement>[],
      revealedSlotIndices: <int>{},
    );
  }

  GameState copyWith({
    Puzzle? currentPuzzle,
    bool clearPuzzle = false,
    List<String?>? selectedLetters,
    List<LetterTile>? availableLetters,
    GameStatus? gameStatus,
    String? currentCategoryId,
    int? hintsUsed,
    int? score,
    int? coins,
    bool? isRepeatSolve,
    List<Achievement>? newlyUnlockedAchievements,
    Set<int>? revealedSlotIndices,
  }) {
    return GameState(
      currentPuzzle: clearPuzzle ? null : (currentPuzzle ?? this.currentPuzzle),
      selectedLetters: selectedLetters ?? this.selectedLetters,
      availableLetters: availableLetters ?? this.availableLetters,
      gameStatus: gameStatus ?? this.gameStatus,
      currentCategoryId: currentCategoryId ?? this.currentCategoryId,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      score: score ?? this.score,
      coins: coins ?? this.coins,
      isRepeatSolve: isRepeatSolve ?? this.isRepeatSolve,
      newlyUnlockedAchievements:
          newlyUnlockedAchievements ?? this.newlyUnlockedAchievements,
      revealedSlotIndices: revealedSlotIndices ?? this.revealedSlotIndices,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        currentPuzzle,
        selectedLetters,
        availableLetters,
        gameStatus,
        currentCategoryId,
        hintsUsed,
        score,
        coins,
        isRepeatSolve,
        newlyUnlockedAchievements,
        revealedSlotIndices,
      ];
}
