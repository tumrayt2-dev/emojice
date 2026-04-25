import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_progress.dart';
import '../services/achievement_service.dart';
import '../services/ad_service.dart';
import '../services/category_service.dart';
import '../services/coin_service.dart';
import '../services/daily_bonus_service.dart';
import '../services/dev_mode_service.dart';
import '../services/haptic_service.dart';
import '../services/letter_service.dart';
import '../services/onboarding_service.dart';
import '../services/progress_service.dart';
import '../services/purchase_service.dart';
import '../services/puzzle_service.dart';
import '../services/unlock_service.dart';

/// Tüm servislerin tek yerde tanımlandığı provider dosyası.

/// Puzzle JSON servisi.
final Provider<PuzzleService> puzzleServiceProvider =
    Provider<PuzzleService>((Ref ref) => PuzzleService());

/// Kategori JSON servisi (puzzle servisine bağlı).
final Provider<CategoryService> categoryServiceProvider =
    Provider<CategoryService>((Ref ref) {
  return CategoryService(puzzleService: ref.watch(puzzleServiceProvider));
});

/// Hive tabanlı ilerleme servisi.
final Provider<ProgressService> progressServiceProvider =
    Provider<ProgressService>((Ref ref) => ProgressService());

/// Coin servisi (progress servisini kullanır).
final Provider<CoinService> coinServiceProvider = Provider<CoinService>((Ref ref) {
  return CoinService(progressService: ref.watch(progressServiceProvider));
});

/// Harf havuzu üretici.
final Provider<LetterService> letterServiceProvider =
    Provider<LetterService>((Ref ref) => LetterService());

/// Hive tabanlı (mock) satın alma servisi.
final Provider<PurchaseService> purchaseServiceProvider =
    Provider<PurchaseService>((Ref ref) => PurchaseService());

/// AdMob (test id'li) reklam servisi.
final Provider<AdService> adServiceProvider = Provider<AdService>((Ref ref) {
  return AdService(
    purchaseService: ref.watch(purchaseServiceProvider),
    devModeService: ref.watch(devModeServiceProvider),
  );
});

/// Oyuncu ilerlemesini async olarak yayınlar.
final FutureProvider<PlayerProgress> playerProgressProvider =
    FutureProvider<PlayerProgress>((Ref ref) async {
  final ProgressService service = ref.watch(progressServiceProvider);
  return service.load();
});

/// Haptik (titreşim) servisi.
final Provider<HapticService> hapticServiceProvider =
    Provider<HapticService>((Ref ref) => const HapticService());

/// Günlük giriş bonusu servisi.
final Provider<DailyBonusService> dailyBonusServiceProvider =
    Provider<DailyBonusService>((Ref ref) {
  return DailyBonusService(coinService: ref.watch(coinServiceProvider));
});

/// Satın alma durumunu async olarak yayınlar (UI yenilemesi için).
final FutureProvider<Set<String>> purchasedProductsProvider =
    FutureProvider<Set<String>>((Ref ref) async {
  final PurchaseService service = ref.watch(purchaseServiceProvider);
  return service.getPurchased();
});

/// Başarım servisi.
final Provider<AchievementService> achievementServiceProvider =
    Provider<AchievementService>((Ref ref) {
  return AchievementService(
    categoryService: ref.watch(categoryServiceProvider),
    puzzleService: ref.watch(puzzleServiceProvider),
    progressService: ref.watch(progressServiceProvider),
    coinService: ref.watch(coinServiceProvider),
  );
});

/// Kategori kilit mantığı (saf hesap).
final Provider<UnlockService> unlockServiceProvider =
    Provider<UnlockService>((Ref ref) => const UnlockService());

/// Dev modu servisi (gizli — versiyon yazısına 5 tıklayınca açılır).
final Provider<DevModeService> devModeServiceProvider =
    Provider<DevModeService>((Ref ref) => DevModeService());

/// Dev modu state'i — UI senkronu için future olarak yayınlanır.
final FutureProvider<DevModeState> devModeStateProvider =
    FutureProvider<DevModeState>((Ref ref) async {
  final DevModeService service = ref.watch(devModeServiceProvider);
  return service.load();
});

/// İlk açılış (onboarding) servisi.
final Provider<OnboardingService> onboardingServiceProvider =
    Provider<OnboardingService>((Ref ref) => OnboardingService());
