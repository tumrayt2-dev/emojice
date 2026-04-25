import 'dart:math';

/// Oyun tahtasındaki harf dizilerini üretmekten sorumlu yardımcı.
class LetterService {
  LetterService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Türkçe büyük harf alfabesi.
  static const List<String> turkishAlphabet = <String>[
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H',
    'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P',
    'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
  ];

  /// Cevap metnindeki (boşluklar hariç) harflerin büyük harf listesini
  /// döndürür. Türkçe 'i' → 'İ' dönüşümü doğru yapılır.
  List<String> lettersOfAnswer(String answer) {
    final List<String> result = <String>[];
    for (final int rune in answer.runes) {
      final String ch = String.fromCharCode(rune);
      if (ch == ' ') {
        continue;
      }
      result.add(_toTurkishUpper(ch));
    }
    return result;
  }

  /// Oyun için karıştırılmış harf havuzu üretir.
  ///
  /// Havuz boyutu: cevaptaki harf sayısı + [extraMin] ile [extraMax]
  /// arasında rastgele ekstra harf. Ekstra harfler Türkçe alfabeden
  /// rastgele seçilir.
  List<String> buildLetterPool(
    String answer, {
    int extraMin = 4,
    int extraMax = 6,
  }) {
    assert(extraMin >= 0 && extraMax >= extraMin);
    final List<String> base = lettersOfAnswer(answer);
    final int extraCount = extraMin == extraMax
        ? extraMin
        : extraMin + _random.nextInt(extraMax - extraMin + 1);

    final List<String> pool = List<String>.from(base);
    for (int i = 0; i < extraCount; i++) {
      pool.add(turkishAlphabet[_random.nextInt(turkishAlphabet.length)]);
    }
    pool.shuffle(_random);
    return pool;
  }

  /// Cevapta boşluk indekslerini döndürür (rune bazlı).
  List<int> spaceIndices(String answer) {
    final List<int> result = <int>[];
    int index = 0;
    for (final int rune in answer.runes) {
      final String ch = String.fromCharCode(rune);
      if (ch == ' ') {
        result.add(index);
      }
      index++;
    }
    return result;
  }

  /// Türkçe karakterler dahil tek karakter büyük harfe çevirir.
  String _toTurkishUpper(String ch) {
    switch (ch) {
      case 'i':
        return 'İ';
      case 'ı':
        return 'I';
      case 'ç':
        return 'Ç';
      case 'ş':
        return 'Ş';
      case 'ğ':
        return 'Ğ';
      case 'ö':
        return 'Ö';
      case 'ü':
        return 'Ü';
      default:
        return ch.toUpperCase();
    }
  }
}
