import '../models/player_progress.dart';
import 'progress_service.dart';

/// Coin ekonomisini yönetir. Bakiyeyi [ProgressService] üzerinden
/// Hive'a yansıtır; oyun katmanı sadece bu servisi kullanır.
class CoinService {
  CoinService({required ProgressService progressService})
      : _progressService = progressService;

  final ProgressService _progressService;

  /// Başlangıç coin miktarı.
  static const int startingCoins = 100;

  /// Doğru cevap başına kazanılan coin.
  static const int rewardPerCorrect = 30;

  /// Reklam izleme ödülü.
  static const int rewardPerAd = 50;

  /// "Harf Aç" ipucu maliyeti.
  static const int costRevealLetter = 50;

  /// "Harf Ele" ipucu maliyeti.
  static const int costEliminateLetters = 30;

  /// Mevcut coin bakiyesini döndürür.
  Future<int> getCoins() async {
    final PlayerProgress progress = await _progressService.load();
    return progress.coins;
  }

  /// Yeterli bakiye var mı?
  Future<bool> hasEnoughCoins(int cost) async {
    final int coins = await getCoins();
    return coins >= cost;
  }

  /// Doğru cevap ödülü ekler, yeni bakiyeyi döndürür.
  Future<int> rewardCorrectAnswer() async {
    final PlayerProgress next =
        await _progressService.addCoins(rewardPerCorrect);
    return next.coins;
  }

  /// Reklam izleme ödülü ekler.
  Future<int> rewardAd() async {
    final PlayerProgress next = await _progressService.addCoins(rewardPerAd);
    return next.coins;
  }

  /// İpucu için coin harcar; yetersizse `null` döndürür.
  Future<int?> spend(int cost) async {
    final bool ok = await hasEnoughCoins(cost);
    if (!ok) {
      return null;
    }
    final PlayerProgress next = await _progressService.spendCoins(cost);
    return next.coins;
  }

  /// Doğrudan coin ekler (promosyon, IAP vs.).
  Future<int> addCoins(int amount) async {
    final PlayerProgress next = await _progressService.addCoins(amount);
    return next.coins;
  }
}
