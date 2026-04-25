import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/player_progress.dart';
import '../../models/puzzle.dart';
import '../../providers/service_providers.dart';
import '../../services/daily_bonus_service.dart';
import '../../services/dev_mode_service.dart';
import '../achievements/achievements_dialog.dart';
import 'daily_bonus_dialog.dart';
import 'dev_mode_dialog.dart';
import 'onboarding_dialog.dart';

/// Uygulamanın açılış ekranı.
///
/// Büyük stilize başlık, dekoratif emoji arka planı, toplam skor ve coin
/// bakiyesi göstergesi ile "Oyna" ve "Nasıl Oynanır?" butonlarını içerir.
/// Ayrıca her gün ilk açılışta günlük bonus dialogu gösterir.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _bonusChecked = false;
  bool _onboardingChecked = false;
  int _versionTapCount = 0;
  DateTime? _firstTapAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Önce onboarding kontrol et — yeni kullanıcı dailyBonus'tan önce
      // tanıtımı görmeli.
      await _checkOnboarding();
      if (!mounted) return;
      await _checkDailyBonus();
    });
  }

  Future<void> _checkOnboarding() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;
    final bool seen =
        await ref.read(onboardingServiceProvider).hasSeen();
    if (seen || !mounted) return;
    await OnboardingDialog.show(context);
  }

  /// Karışık moda başlar: tüm puzzle havuzundan (öncelik çözülmemişler)
  /// rastgele bir puzzle seçip `/random/:puzzleId` rotasına yönlendirir.
  Future<void> _startRandomMode(WidgetRef ref) async {
    final List<Puzzle> all = await ref.read(puzzleServiceProvider).loadAll();
    if (!mounted || all.isEmpty) {
      return;
    }
    final PlayerProgress progress =
        await ref.read(progressServiceProvider).load();
    if (!mounted) {
      return;
    }
    final List<Puzzle> unsolved = <Puzzle>[
      for (final Puzzle p in all)
        if (!progress.isSolved(p.categoryId, p.id)) p,
    ];
    final List<Puzzle> pool = unsolved.isNotEmpty ? unsolved : all;
    final math.Random rng = math.Random();
    final Puzzle pick = pool[rng.nextInt(pool.length)];
    if (!mounted) {
      return;
    }
    context.go('/random/${pick.id}');
  }

  /// Versiyon yazısına 5 kez (3 saniye içinde) tıklayınca dev modu açar veya
  /// zaten açıksa dev menüsünü gösterir.
  Future<void> _onVersionTap() async {
    final DateTime now = DateTime.now();
    if (_firstTapAt == null ||
        now.difference(_firstTapAt!) > const Duration(seconds: 3)) {
      _firstTapAt = now;
      _versionTapCount = 1;
    } else {
      _versionTapCount++;
    }

    final DevModeService service = ref.read(devModeServiceProvider);
    await service.load();
    final bool alreadyEnabled = service.current.enabled;

    // Dev mod zaten açıksa tek tıklama → menüyü aç (kolay erişim).
    if (alreadyEnabled) {
      _versionTapCount = 0;
      _firstTapAt = null;
      if (!mounted) return;
      await DevModeDialog.show(context);
      return;
    }

    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      _firstTapAt = null;
      await service.setEnabled(true);
      ref.invalidate(devModeStateProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🛠️ Dev modu açıldı')),
      );
      await DevModeDialog.show(context);
    }
  }

  Future<void> _checkDailyBonus() async {
    if (_bonusChecked) {
      return;
    }
    _bonusChecked = true;
    try {
      final DailyBonusResult result =
          await ref.read(dailyBonusServiceProvider).claimIfAvailable();
      if (!mounted || !result.granted) {
        return;
      }
      // Coin / progress göstergesini tazele.
      ref.invalidate(playerProgressProvider);
      await ref.read(hapticServiceProvider).levelComplete();
      if (!mounted) {
        return;
      }
      await DailyBonusDialog.show(context, result);
    } catch (_) {
      // Sessizce yut — bonus kritik bir özellik değil.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<PlayerProgress> progressAsync =
        ref.watch(playerProgressProvider);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          const _AnimatedEmojiBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: <Widget>[
                  _TopBar(progressAsync: progressAsync),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(height: 12),
                          const _LogoBlock(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  _PlayButton(
                    onPressed: () => context.go('/categories'),
                  ),
                  const SizedBox(height: 10),
                  _RandomModeButton(onPressed: () => _startRandomMode(ref)),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.4,
                              ),
                              width: 1.5,
                            ),
                          ),
                          onPressed: () => context.go('/how-to-play'),
                          icon: const Icon(Icons.help_outline_rounded),
                          label: const Text('Nasıl Oynanır?'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: AppTheme.secondaryColor.withValues(
                                alpha: 0.6,
                              ),
                              width: 1.5,
                            ),
                          ),
                          onPressed: () => context.go('/store'),
                          icon: const Icon(
                            Icons.shopping_bag_rounded,
                            color: AppTheme.secondaryColor,
                          ),
                          label: const Text(
                            'Mağaza',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _FreeCoinButton(),
                  const SizedBox(height: 10),
                  const _AchievementsButton(),
                  const SizedBox(height: 12),
                  const _OtherGamesSection(),
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onVersionTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Emojice • Offline • v1.0.0',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skor ve coin göstergelerini içeren üst bar.
class _TopBar extends ConsumerWidget {
  const _TopBar({required this.progressAsync});

  final AsyncValue<PlayerProgress> progressAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int score = progressAsync.maybeWhen<int>(
      data: (PlayerProgress p) => p.totalScore,
      orElse: () => 0,
    );
    final int coins = progressAsync.maybeWhen<int>(
      data: (PlayerProgress p) => p.coins,
      orElse: () => 0,
    );
    final AsyncValue<DevModeState> devAsync =
        ref.watch(devModeStateProvider);
    final bool devOn = devAsync.maybeWhen<bool>(
      data: (DevModeState s) => s.enabled,
      orElse: () => false,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (devOn) ...<Widget>[
          GestureDetector(
            onTap: () => DevModeDialog.show(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '🛠️',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        _StatChip(
          emoji: '🏆',
          value: score.toString(),
        ),
        const SizedBox(width: 8),
        _StatChip(
          emoji: '💰',
          value: coins.toString(),
          onTap: () => context.go('/store'),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.emoji,
    required this.value,
    this.onTap,
  });

  final String emoji;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(14);
    final Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: radius,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 5),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Stilize başlık + dekoratif emojiler.
class _LogoBlock extends StatelessWidget {
  const _LogoBlock();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('🎬', style: TextStyle(fontSize: 44)),
            SizedBox(width: 8),
            Text('🎯', style: TextStyle(fontSize: 64)),
            SizedBox(width: 8),
            Text('🎵', style: TextStyle(fontSize: 44)),
          ],
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: <Color>[
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
              ],
            ).createShader(bounds);
          },
          child: Text(
            'EMOJİCE',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 4.0,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'EMOJI TAHMİN',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 6.0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Gradient dolgulu büyük "Oyna" butonu.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Oyna',
      child: SizedBox(
      width: double.infinity,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: <Color>[
              AppTheme.primaryColor,
              Color(0xFFB388FF),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'OYNA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Ana menüde "OYNA" butonunun altında yer alan karışık mod butonu.
///
/// Gradient dolgulu, "🎲 Karışık Mod" metinli, dikkat çekici ama ana OYNA
/// butonundan daha hafif bir görsel hiyerarşide.
class _RandomModeButton extends StatelessWidget {
  const _RandomModeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Karışık Mod',
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: <Color>[
                AppTheme.secondaryColor,
                Color(0xFFFF8A65),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppTheme.secondaryColor.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('🎲', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 10),
                    Text(
                      'Karışık Mod',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hafif hareketli, arka planda yüzen emoji dekorasyonu.
class _AnimatedEmojiBackground extends StatefulWidget {
  const _AnimatedEmojiBackground();

  @override
  State<_AnimatedEmojiBackground> createState() =>
      _AnimatedEmojiBackgroundState();
}

class _AnimatedEmojiBackgroundState extends State<_AnimatedEmojiBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<_FloatingEmoji> _emojis = <_FloatingEmoji>[
    _FloatingEmoji(emoji: '🎬', dx: 0.08, dy: 0.12, size: 36),
    _FloatingEmoji(emoji: '🎵', dx: 0.82, dy: 0.18, size: 32),
    _FloatingEmoji(emoji: '📖', dx: 0.12, dy: 0.72, size: 30),
    _FloatingEmoji(emoji: '⚽', dx: 0.78, dy: 0.66, size: 34),
    _FloatingEmoji(emoji: '🍕', dx: 0.88, dy: 0.38, size: 28),
    _FloatingEmoji(emoji: '🌍', dx: 0.05, dy: 0.45, size: 30),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            children: <Widget>[
              for (int i = 0; i < _emojis.length; i++)
                Positioned(
                  left: _emojis[i].dx * size.width,
                  top: _emojis[i].dy * size.height +
                      (i.isEven ? 1 : -1) * 8 * _controller.value,
                  child: Opacity(
                    opacity: 0.15,
                    child: Text(
                      _emojis[i].emoji,
                      style: TextStyle(fontSize: _emojis[i].size),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "Diğer Oyunlarımız" cross-promotion bölümü.
/// Şimdilik boş — ileride Taboo Rush gibi diğer oyunlar eklenecek.
class _OtherGamesSection extends StatelessWidget {
  const _OtherGamesSection();

  // İleride şu yapı ile genişletilecek:
  // {name, icon, storeUrl} listesi ve tıklanabilir kartlar.
  static const List<Map<String, String>> _games = <Map<String, String>>[];

  @override
  Widget build(BuildContext context) {
    if (_games.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Diğer Oyunlarımız',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Map<String, String> g in _games)
                Chip(
                  avatar: Text(g['icon'] ?? '🎮'),
                  label: Text(g['name'] ?? ''),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingEmoji {
  const _FloatingEmoji({
    required this.emoji,
    required this.dx,
    required this.dy,
    required this.size,
  });

  final String emoji;
  final double dx;
  final double dy;
  final double size;
}

/// Rewarded reklam izleyip anında +50 jeton kazandıran küçük buton.
///
/// Reklam başarısız olursa sessizce kapanır (SnackBar göstermez).
class _FreeCoinButton extends ConsumerWidget {
  const _FreeCoinButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.18),
          foregroundColor: AppTheme.secondaryColor,
        ),
        onPressed: () => _watchAdForCoins(context, ref),
        icon: const Text('🎁', style: TextStyle(fontSize: 18)),
        label: const Text(
          'Bedava Jeton',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _watchAdForCoins(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool watched =
        await ref.read(adServiceProvider).showRewardedAd(context);
    if (!watched) {
      // Reklam tamamlanmadı — sessizce çık.
      return;
    }
    await ref.read(coinServiceProvider).rewardAd();
    ref.invalidate(playerProgressProvider);
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Bedava 50 jeton kazandın!')),
    );
  }
}

/// Ana menüde başarımları açan buton.
class _AchievementsButton extends StatelessWidget {
  const _AchievementsButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.14),
          foregroundColor: AppTheme.primaryColor,
        ),
        onPressed: () => AchievementsDialog.show(context),
        icon: const Text('🏆', style: TextStyle(fontSize: 18)),
        label: const Text(
          'Başarımlar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
