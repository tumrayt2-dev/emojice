import 'package:equatable/equatable.dart';

/// Kategori açma şartı türü.
enum UnlockType {
  /// Şart yok, hep açık.
  none,

  /// Oyuncunun toplam çözdüğü puzzle sayısına göre açılır.
  totalSolved,

  /// Toplam + başka bir kategoriden belirli sayıda çözüm gerekir.
  chain,
}

/// Kategori açma şartı. `null` → hep açık (T1).
class UnlockRequirement extends Equatable {
  const UnlockRequirement({
    required this.type,
    required this.tierValue,
    this.chainTarget,
    this.chainValue,
  });

  /// Şart türü.
  final UnlockType type;

  /// Tier eşiği (Bulmaca Puanı). Bu değer reklam puanı dahil efektif puan ile
  /// karşılaştırılır.
  final int tierValue;

  /// `chain` türünde hedef kategori id'si.
  final String? chainTarget;

  /// `chain` türünde hedef kategoride gereken çözüm sayısı.
  final int? chainValue;

  factory UnlockRequirement.fromJson(Map<String, dynamic> json) {
    final String typeStr = json['type'] as String? ?? 'none';
    final UnlockType t = switch (typeStr) {
      'totalSolved' => UnlockType.totalSolved,
      'chain' => UnlockType.chain,
      _ => UnlockType.none,
    };
    return UnlockRequirement(
      type: t,
      tierValue: (json['value'] as num?)?.toInt() ?? 0,
      chainTarget: json['chainTarget'] as String?,
      chainValue: (json['chainValue'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': switch (type) {
          UnlockType.totalSolved => 'totalSolved',
          UnlockType.chain => 'chain',
          UnlockType.none => 'none',
        },
        'value': tierValue,
        if (chainTarget != null) 'chainTarget': chainTarget,
        if (chainValue != null) 'chainValue': chainValue,
      };

  @override
  List<Object?> get props =>
      <Object?>[type, tierValue, chainTarget, chainValue];
}

/// Oyun içi bulmaca kategorisi.
class PuzzleCategory extends Equatable {
  const PuzzleCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.puzzleCount,
    required this.isPremium,
    this.unlock,
  });

  /// Kategori kimliği (ör. "movies").
  final String id;

  /// Görünen ad (ör. "Filmler").
  final String name;

  /// Kategori ikonu (tek emoji).
  final String icon;

  /// Bu kategorideki toplam soru sayısı.
  final int puzzleCount;

  /// Kategori premium mi?
  final bool isPremium;

  /// Kategori açma şartı. `null` → hep açık.
  final UnlockRequirement? unlock;

  factory PuzzleCategory.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? unlockJson =
        json['unlock'] as Map<String, dynamic>?;
    return PuzzleCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      puzzleCount: (json['puzzleCount'] as num?)?.toInt() ?? 0,
      isPremium: json['isPremium'] as bool? ?? false,
      unlock:
          unlockJson != null ? UnlockRequirement.fromJson(unlockJson) : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'icon': icon,
        'puzzleCount': puzzleCount,
        'isPremium': isPremium,
        if (unlock != null) 'unlock': unlock!.toJson(),
      };

  PuzzleCategory copyWith({
    String? id,
    String? name,
    String? icon,
    int? puzzleCount,
    bool? isPremium,
    UnlockRequirement? unlock,
  }) {
    return PuzzleCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      puzzleCount: puzzleCount ?? this.puzzleCount,
      isPremium: isPremium ?? this.isPremium,
      unlock: unlock ?? this.unlock,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[id, name, icon, puzzleCount, isPremium, unlock];
}
