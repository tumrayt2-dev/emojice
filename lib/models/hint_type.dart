/// İpucu türleri ve maliyetleri.
enum HintType {
  /// Rastgele bir doğru harfi yerine koyar (50 coin).
  revealLetter(cost: 50, label: 'Harf Aç'),

  /// 3 yanlış harfi kaldırır (30 coin).
  eliminateLetters(cost: 30, label: 'Harf Ele');

  const HintType({required this.cost, required this.label});

  /// Coin cinsinden maliyet.
  final int cost;

  /// UI'da gösterilecek Türkçe etiket.
  final String label;
}
