// Temel smoke test — ana ekran yükleniyor mu?
//
// Hive'a (ve dolayısıyla path_provider plugin'ine) bağımlı kalmamak için
// `playerProgressProvider` ve `dailyBonusServiceProvider`'ı override
// ediyoruz. Bu sayede `Hive.openBox` hiç çağrılmadan HomeScreen test
// edilebiliyor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emoji_tahmin/features/home/home_screen.dart';
import 'package:emoji_tahmin/models/player_progress.dart';
import 'package:emoji_tahmin/providers/service_providers.dart';
import 'package:emoji_tahmin/services/coin_service.dart';
import 'package:emoji_tahmin/services/daily_bonus_service.dart';
import 'package:emoji_tahmin/services/dev_mode_service.dart';
import 'package:emoji_tahmin/services/onboarding_service.dart';
import 'package:emoji_tahmin/services/progress_service.dart';

/// Test ortamında Hive açmadan no-op davranan günlük bonus servisi.
/// `super` constructor için sahte bir CoinService geçiriyoruz; sonra
/// metodları override ettiğimiz için bu servisin metodları hiç çağrılmıyor.
class _NoopDailyBonusService extends DailyBonusService {
  _NoopDailyBonusService()
      : super(coinService: CoinService(progressService: ProgressService()));

  @override
  Future<DailyBonusResult> claimIfAvailable() async {
    return const DailyBonusResult(
      granted: false,
      amount: 0,
      streakDay: 0,
      newCoinBalance: 0,
    );
  }

  @override
  Future<int> currentStreak() async => 0;
}

/// Test ortamında Hive açmadan onboarding'i "görüldü" olarak döner.
class _NoopOnboardingService extends OnboardingService {
  _NoopOnboardingService();

  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Ana ekran açılıyor mu?', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          playerProgressProvider.overrideWith(
            (Ref ref) async => PlayerProgress.initial(),
          ),
          dailyBonusServiceProvider.overrideWithValue(
            _NoopDailyBonusService(),
          ),
          devModeStateProvider.overrideWith(
            (Ref ref) async => DevModeState.off,
          ),
          onboardingServiceProvider.overrideWithValue(
            _NoopOnboardingService(),
          ),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Async provider'ın çözülmesi için bir frame bekle.
    await tester.pump();

    expect(find.text('EMOJİCE'), findsOneWidget);
    expect(find.text('OYNA'), findsOneWidget);
    expect(find.text('Nasıl Oynanır?'), findsOneWidget);
  });
}
