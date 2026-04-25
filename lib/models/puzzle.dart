import 'package:equatable/equatable.dart';

/// Tek bir emoji-tahmin bulmacası.
class Puzzle extends Equatable {
  const Puzzle({
    required this.id,
    required this.emojis,
    required this.answer,
    required this.category,
    required this.categoryId,
    required this.difficulty,
    required this.letterCount,
    required this.isPremium,
  });

  /// Benzersiz soru kimliği (ör. "movies_1").
  final String id;

  /// Emoji kombinasyonu (ör. "🦁👑").
  final String emojis;

  /// Doğru cevap metni (ör. "Aslan Kral").
  final String answer;

  /// Kategori görünen adı (ör. "Filmler").
  final String category;

  /// Kategori kimliği (ör. "movies").
  final String categoryId;

  /// Zorluk: 1 kolay, 2 orta, 3 zor.
  final int difficulty;

  /// Cevaptaki harf sayısı (boşluklar hariç).
  final int letterCount;

  /// Premium içerik mi?
  final bool isPremium;

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String,
      emojis: json['emojis'] as String,
      answer: json['answer'] as String,
      category: json['category'] as String,
      categoryId: json['categoryId'] as String,
      difficulty: (json['difficulty'] as num).toInt(),
      letterCount: (json['letterCount'] as num).toInt(),
      isPremium: json['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'emojis': emojis,
        'answer': answer,
        'category': category,
        'categoryId': categoryId,
        'difficulty': difficulty,
        'letterCount': letterCount,
        'isPremium': isPremium,
      };

  Puzzle copyWith({
    String? id,
    String? emojis,
    String? answer,
    String? category,
    String? categoryId,
    int? difficulty,
    int? letterCount,
    bool? isPremium,
  }) {
    return Puzzle(
      id: id ?? this.id,
      emojis: emojis ?? this.emojis,
      answer: answer ?? this.answer,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      difficulty: difficulty ?? this.difficulty,
      letterCount: letterCount ?? this.letterCount,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        emojis,
        answer,
        category,
        categoryId,
        difficulty,
        letterCount,
        isPremium,
      ];
}
