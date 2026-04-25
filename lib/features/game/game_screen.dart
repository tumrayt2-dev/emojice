import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/game_state.dart';
import '../../models/hint_type.dart';
import '../../models/player_progress.dart';
import '../../models/puzzle.dart';
import '../../providers/game_controller.dart';
import '../../providers/service_providers.dart';
import '../../services/achievement_service.dart';

/// Karışık mod sabiti — GameController.mixCategoryId ile eş değer.
const String _kMixCategoryId = '__mix__';

/// Aktif oyun ekranı — tüm oyun deneyimi burada yaşanır.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    required this.categoryId,
    required this.puzzleId,
  });

  final String categoryId;
  final String puzzleId;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _shakeController;
  late final AnimationController _rewardController;

  bool _initialized = false;
  bool _solvedDialogShown = false;
  bool _alreadySolvedNoticeShown = false;
  Timer? _failTimer;
  Timer? _solvedTimer;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _rewardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPuzzle();
    });
  }

  @override
  void didUpdateWidget(covariant GameScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId ||
        oldWidget.puzzleId != widget.puzzleId) {
      _initialized = false;
      _solvedDialogShown = false;
      _alreadySolvedNoticeShown = false;
      _failTimer?.cancel();
      _solvedTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPuzzle();
      });
    }
  }

  Future<void> _loadPuzzle() async {
    await ref.read(gameControllerProvider.notifier).loadPuzzle(
          categoryId: widget.categoryId,
          puzzleId: widget.puzzleId,
        );
    if (!mounted) {
      return;
    }
    setState(() => _initialized = true);

    // Eğer bu soru daha önce çözülmüşse kullanıcıyı bilgilendir.
    // Karışık modda puzzle'ın kendi asıl categoryId'sine göre kontrol ederiz.
    final Puzzle? current = ref.read(gameControllerProvider).currentPuzzle;
    if (current == null) {
      return;
    }
    final PlayerProgress progress = await ref.read(progressServiceProvider).load();
    if (!mounted) {
      return;
    }
    if (progress.isSolved(current.categoryId, current.id) &&
        !_alreadySolvedNoticeShown) {
      _alreadySolvedNoticeShown = true;
      // Slotları doğru cevapla önden doldur; kullanıcı harfleri kaldırarak
      // tekrar oynayabilir. GameStatus.playing korunur.
      if (ref.read(gameControllerProvider).gameStatus == GameStatus.playing) {
        ref.read(gameControllerProvider.notifier).prefillSolution();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu soruyu daha önce çözdün — tekrar oynayabilirsin.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _failTimer?.cancel();
    _solvedTimer?.cancel();
    _confettiController.dispose();
    _shakeController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  void _onStateChange(GameState? prev, GameState next) {
    // Yanlış cevap → shake + uzun titreşim + 600ms sonra sıfırla.
    if (prev?.gameStatus != GameStatus.failed &&
        next.gameStatus == GameStatus.failed) {
      _shakeController.forward(from: 0);
      unawaited(ref.read(hapticServiceProvider).wrongAnswer());
      _failTimer?.cancel();
      _failTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) {
          return;
        }
        ref.read(gameControllerProvider.notifier).resetPuzzle();
      });
    }

    // Doğru cevap → konfeti + çift titreşim + 1.5s sonra dialog.
    if (prev?.gameStatus != GameStatus.solved &&
        next.gameStatus == GameStatus.solved) {
      _confettiController.play();
      _rewardController.forward(from: 0);
      _solvedDialogShown = false;
      unawaited(ref.read(hapticServiceProvider).correctAnswer());
      // Progress cache'i invalidate et — kategori/levels ekranları
      // çözülmüş bilgisini yeniden yüklesin.
      ref.invalidate(playerProgressProvider);
      // Reklam servisine bildir — eşik dolduysa interstitial gösterilecek.
      // Reklam kaldırma satın alındıysa ad servisi içeride no-op döner.
      unawaited(ref.read(adServiceProvider).notifyPuzzleSolved());
      _solvedTimer?.cancel();
      final bool fastDialog =
          ref.read(devModeServiceProvider).current.fastSolvedDialog;
      final Duration delay = fastDialog
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 1500);
      _solvedTimer = Timer(delay, () {
        if (!mounted || _solvedDialogShown) {
          return;
        }
        _solvedDialogShown = true;
        _showSolvedDialog(next);
      });
    }
  }

  Future<void> _showSolvedDialog(GameState state) async {
    final Puzzle? puzzle = state.currentPuzzle;
    if (puzzle == null) {
      return;
    }
    final int stars = state.hintsUsed == 0
        ? 3
        : state.hintsUsed == 1
            ? 2
            : 1;

    final bool isMix = widget.categoryId == _kMixCategoryId;

    // Sıradaki soruyu belirle.
    String? nextRouteTarget;
    bool categoryComplete = false;

    if (isMix) {
      // Karışık modda: önceliği henüz çözülmemişler — yoksa tüm havuzdan
      // rastgele. Mevcut puzzle'ı aday listeden çıkar.
      final List<Puzzle> all = await ref.read(puzzleServiceProvider).loadAll();
      if (!mounted) {
        return;
      }
      final PlayerProgress progress =
          await ref.read(progressServiceProvider).load();
      if (!mounted) {
        return;
      }
      final List<Puzzle> candidates = <Puzzle>[
        for (final Puzzle p in all)
          if (p.id != puzzle.id) p,
      ];
      final List<Puzzle> unsolved = <Puzzle>[
        for (final Puzzle p in candidates)
          if (!progress.isSolved(p.categoryId, p.id)) p,
      ];
      final List<Puzzle> pool = unsolved.isNotEmpty ? unsolved : candidates;
      if (pool.isEmpty) {
        // Çözülecek başka puzzle kalmadı (tek puzzle'lı durum).
        categoryComplete = true;
      } else {
        final math.Random rng = math.Random();
        final Puzzle next = pool[rng.nextInt(pool.length)];
        nextRouteTarget = '/random/${next.id}';
      }
    } else {
      // Klasik (kategori içi) mod: sayı bazlı tamamlanma + sıradaki çözülmemiş.
      final List<Puzzle> all = await ref
          .read(puzzleServiceProvider)
          .byCategory(widget.categoryId);
      if (!mounted) {
        return;
      }
      final PlayerProgress progress =
          await ref.read(progressServiceProvider).load();
      if (!mounted) {
        return;
      }
      // Kategori tamamlandı = bütün puzzle id'leri çözülmüş.
      final int solvedCount = progress.solvedCountFor(widget.categoryId);
      categoryComplete = solvedCount >= all.length;

      if (!categoryComplete) {
        // Henüz çözülmemiş ilk puzzle'ı bul.
        Puzzle? unsolved;
        for (final Puzzle p in all) {
          if (p.id == puzzle.id) continue;
          if (!progress.isSolved(widget.categoryId, p.id)) {
            unsolved = p;
            break;
          }
        }
        // Hepsi çözülmüş ama kategori tamamlanmadı (mevcut puzzle hariç) →
        // bu mevcutu son çözen kullanıcıdır; tamamla.
        if (unsolved == null) {
          categoryComplete = true;
        } else {
          nextRouteTarget = '/game/${widget.categoryId}/${unsolved.id}';
        }
      }
    }

    if (categoryComplete) {
      unawaited(ref.read(hapticServiceProvider).levelComplete());
    }

    final bool isRepeat = state.isRepeatSolve;
    final int coinsEarned = isRepeat ? 0 : 30;
    final List<Achievement> newlyUnlocked =
        List<Achievement>.from(state.newlyUnlockedAchievements);

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (BuildContext ctx) {
        return _SolvedSheet(
          puzzle: puzzle,
          stars: stars,
          score: state.score,
          coinsEarned: coinsEarned,
          categoryComplete: categoryComplete,
          isMix: isMix,
          isRepeat: isRepeat,
          newlyUnlockedAchievements: newlyUnlocked,
          onNext: () {
            Navigator.of(ctx).pop();
            if (categoryComplete) {
              if (isMix) {
                // Karışık modda "kategoriye dön" anlamsız — ana ekrana.
                context.go('/');
              } else {
                context.go('/levels/${widget.categoryId}');
              }
              return;
            }
            if (nextRouteTarget != null) {
              context.go(nextRouteTarget);
            }
          },
          onHome: () {
            Navigator.of(ctx).pop();
            context.go('/');
          },
        );
      },
    );

    // Dialog gösterildi — tekrar tekrar gösterilmesin diye temizle.
    if (mounted) {
      ref.read(gameControllerProvider.notifier)
          .consumeNewlyUnlockedAchievements();
    }
  }

  Future<void> _onHintTap(HintType type) async {
    final GameState st = ref.read(gameControllerProvider);
    if (st.coins < type.cost) {
      await _showInsufficientCoinDialog();
      return;
    }
    unawaited(ref.read(hapticServiceProvider).hintUsed());
    await ref.read(gameControllerProvider.notifier).useHint(type);
  }

  Future<void> _showInsufficientCoinDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Coin'in yeterli değil!"),
          content: const Text(
              'İpucu kullanmak için biraz coin gerek. Reklam izleyerek hemen kazanabilirsin.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İpuçsuz Devam Et'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mağaza yakında geliyor.'),
                  ),
                );
              },
              child: const Text('Mağaza'),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _watchMockAd();
              },
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Reklam İzle (+50)'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _watchMockAd() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // Gerçek AdMob rewarded ad — yüklenemezse mock fallback (3sn dialog).
    final bool watched =
        await ref.read(adServiceProvider).showRewardedAd(context);
    if (!watched) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Reklam tamamlanamadı.')),
      );
      return;
    }
    final int newCoins = await ref.read(coinServiceProvider).rewardAd();
    if (!mounted) {
      return;
    }
    // State'teki coin alanını güncelle.
    ref.read(gameControllerProvider.notifier).syncCoins(newCoins);

    messenger.showSnackBar(
      const SnackBar(content: Text('+50 coin kazandın!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameControllerProvider, _onStateChange);
    final GameState state = ref.watch(gameControllerProvider);
    final ThemeData theme = Theme.of(context);

    final bool isMix = widget.categoryId == _kMixCategoryId;
    final String backRoute =
        isMix ? '/categories' : '/levels/${widget.categoryId}';

    if (!_initialized || state.currentPuzzle == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isMix ? 'Karışık Mod' : 'Oyun'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(backRoute),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final Puzzle puzzle = state.currentPuzzle!;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMix ? 'Karışık Mod' : puzzle.category),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(backRoute),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CoinBadge(coins: state.coins),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 16),
                _EmojiArea(emojis: puzzle.emojis),
                const SizedBox(height: 16),
                _AnswerSlots(
                  answer: puzzle.answer,
                  selectedLetters: state.selectedLetters,
                  status: state.gameStatus,
                  shakeController: _shakeController,
                  onSlotTap: (int slotIndex) => ref
                      .read(gameControllerProvider.notifier)
                      .removeLetter(slotIndex),
                ),
                const SizedBox(height: 12),
                _HintBar(
                  coins: state.coins,
                  onHint: _onHintTap,
                  enabled: state.gameStatus == GameStatus.playing,
                ),
                const Spacer(),
                _LetterPool(
                  tiles: state.availableLetters,
                  enabled: state.gameStatus == GameStatus.playing,
                  onTap: (int index) {
                    unawaited(ref.read(hapticServiceProvider).letterTap());
                    ref
                        .read(gameControllerProvider.notifier)
                        .selectLetter(index);
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Kazanım yazısı animasyonu.
          if (state.gameStatus == GameStatus.solved)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _rewardController,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _rewardController.value;
                    final String bannerText = state.isRepeatSolve
                        ? 'Doğru! (Tekrar — ödül yok)'
                        : '+${state.score} puan  •  +30 💰  •  +1 Bulmaca Puanı';
                    return Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -60 * t),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              bannerText,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Konfeti.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 24,
              gravity: 0.25,
              emissionFrequency: 0.05,
              colors: const <Color>[
                Colors.amber,
                Colors.pinkAccent,
                Colors.lightBlueAccent,
                Colors.greenAccent,
                Colors.purpleAccent,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Üst kısım: emoji alanı
// =============================================================================
class _EmojiArea extends StatelessWidget {
  const _EmojiArea({required this.emojis});

  final String emojis;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppTheme.primaryColor.withValues(alpha: 0.12),
            AppTheme.secondaryColor.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          emojis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 72, height: 1.1),
        ),
      ),
    );
  }
}

// =============================================================================
// Coin göstergesi
// =============================================================================
class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (Widget child, Animation<double> anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey<int>(coins),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('💰', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              '$coins',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Cevap slotları
// =============================================================================
class _AnswerSlots extends StatelessWidget {
  const _AnswerSlots({
    required this.answer,
    required this.selectedLetters,
    required this.status,
    required this.shakeController,
    required this.onSlotTap,
  });

  final String answer;
  final List<String?> selectedLetters;
  final GameStatus status;
  final AnimationController shakeController;
  final ValueChanged<int> onSlotTap;

  @override
  Widget build(BuildContext context) {
    // Cevap kelimelere bölünür; her kelime Row içinde (asla bölünmez),
    // kelimeler arası Wrap devreye girer. Slot boyutu, en uzun kelime
    // mevcut genişliğe sığacak şekilde adaptif hesaplanır.
    final List<String> words = answer.split(' ');

    return AnimatedBuilder(
      animation: shakeController,
      builder: (BuildContext context, Widget? child) {
        final double offset = math.sin(shakeController.value * math.pi * 6) *
            8 *
            (1 - shakeController.value);
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double availW = constraints.maxWidth;
            const double slotSpacing = 6;
            const double wordSpacing = 14;
            const double maxSlotW = 34;
            const double minSlotW = 18;

            // En uzun kelimenin harf sayısı — bu kelime tek satıra sığmalı.
            int longest = 0;
            for (final String w in words) {
              if (w.runes.length > longest) {
                longest = w.runes.length;
              }
            }
            if (longest == 0) {
              longest = 1;
            }

            // Hedef: en uzun kelime tek başına tek satırda sığsın.
            // Gerekirse tüm kelimeler tek satırda sığmayı dene; sığmazsa
            // Wrap kelimeler arasında devreye girer.
            final int totalLetters =
                words.fold<int>(0, (int a, String w) => a + w.runes.length);
            final int gapsAll = words.length - 1;

            double widthForTotal(double s) =>
                totalLetters * s + (totalLetters - 1) * slotSpacing +
                    gapsAll * (wordSpacing - slotSpacing);

            double slotW = maxSlotW;
            // Önce hepsi tek satıra sığıyor mu?
            if (widthForTotal(slotW) > availW) {
              // Sığmıyorsa Wrap devrede; en az en uzun kelime sığmalı.
              // slotW = (availW - (longest-1)*slotSpacing) / longest
              final double maxByLongest =
                  (availW - (longest - 1) * slotSpacing) / longest;
              slotW = math.min(maxSlotW, maxByLongest);
            }
            slotW = slotW.clamp(minSlotW, maxSlotW);
            final double slotH = slotW * 1.28;
            final double fontSize = slotW * 0.58;

            int letterCursor = 0;
            final List<Widget> wordWidgets = <Widget>[];
            for (int w = 0; w < words.length; w++) {
              final String word = words[w];
              final int len = word.runes.length;
              final List<Widget> boxes = <Widget>[];
              for (int i = 0; i < len; i++) {
                final int slotIndex = letterCursor;
                final String? letter = slotIndex < selectedLetters.length
                    ? selectedLetters[slotIndex]
                    : null;
                if (i > 0) {
                  boxes.add(const SizedBox(width: slotSpacing));
                }
                boxes.add(
                  _SlotBox(
                    letter: letter,
                    status: status,
                    onTap: () => onSlotTap(slotIndex),
                    width: slotW,
                    height: slotH,
                    fontSize: fontSize,
                  ),
                );
                letterCursor++;
              }
              wordWidgets.add(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: boxes,
                ),
              );
            }

            return Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: wordSpacing,
              runSpacing: 8,
              children: wordWidgets,
            );
          },
        ),
      ),
    );
  }
}

class _SlotBox extends StatelessWidget {
  const _SlotBox({
    required this.letter,
    required this.status,
    required this.onTap,
    this.width = 34,
    this.height = 44,
    this.fontSize = 20,
  });

  final String? letter;
  final GameStatus status;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Color borderColor = theme.colorScheme.outline.withValues(alpha: 0.4);
    Color background = theme.colorScheme.surface;
    Color textColor = theme.colorScheme.onSurface;

    if (status == GameStatus.solved && letter != null) {
      borderColor = Colors.green;
      background = Colors.green.withValues(alpha: 0.18);
      textColor = Colors.green[900]!;
    } else if (status == GameStatus.failed && letter != null) {
      borderColor = Colors.redAccent;
      background = Colors.red.withValues(alpha: 0.15);
      textColor = Colors.red[900]!;
    } else if (letter != null) {
      borderColor = AppTheme.primaryColor.withValues(alpha: 0.7);
      background = AppTheme.primaryColor.withValues(alpha: 0.08);
    }

    final String slotLabel =
        letter == null ? 'Boş slot' : 'Seçilen harf $letter';
    return Semantics(
      label: slotLabel,
      button: letter != null,
      child: GestureDetector(
      onTap: letter == null ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Text(
          letter ?? '',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
    ),
    );
  }
}

// =============================================================================
// İpucu butonları
// =============================================================================
class _HintBar extends StatelessWidget {
  const _HintBar({
    required this.coins,
    required this.onHint,
    required this.enabled,
  });

  final int coins;
  final ValueChanged<HintType> onHint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _HintButton(
              icon: '💡',
              label: 'Harf Aç',
              cost: HintType.revealLetter.cost,
              hasCoins: coins >= HintType.revealLetter.cost,
              enabled: enabled,
              onPressed: () => onHint(HintType.revealLetter),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _HintButton(
              icon: '❌',
              label: 'Harf Ele',
              cost: HintType.eliminateLetters.cost,
              hasCoins: coins >= HintType.eliminateLetters.cost,
              enabled: enabled,
              onPressed: () => onHint(HintType.eliminateLetters),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({
    required this.icon,
    required this.label,
    required this.cost,
    required this.hasCoins,
    required this.enabled,
    required this.onPressed,
  });

  final String icon;
  final String label;
  final int cost;
  final bool hasCoins;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isActive = enabled && hasCoins;
    // Coin yetmiyorsa buton "disabled" görünür ama tap hâlâ çalışır
    // (üst katman yetersiz coin dialog'unu gösterir).
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label, $cost coin',
      child: Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? AppTheme.primaryColor.withValues(alpha: 0.5)
                    : theme.colorScheme.outline.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$label ($cost 💰)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                if (!isActive && enabled) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

// =============================================================================
// Harf havuzu
// =============================================================================
class _LetterPool extends StatelessWidget {
  const _LetterPool({
    required this.tiles,
    required this.enabled,
    required this.onTap,
  });

  final List<LetterTile> tiles;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (int i = 0; i < tiles.length; i++)
            _PoolTile(
              tile: tiles[i],
              enabled: enabled && !tiles[i].isUsed && !tiles[i].isEliminated,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _PoolTile extends StatefulWidget {
  const _PoolTile({
    required this.tile,
    required this.enabled,
    required this.onTap,
  });

  final LetterTile tile;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PoolTile> createState() => _PoolTileState();
}

class _PoolTileState extends State<_PoolTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward(from: 0.85);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isUsed = widget.tile.isUsed;
    final bool isEliminated = widget.tile.isEliminated;

    Color background;
    Color borderColor;
    Color textColor;

    if (isEliminated) {
      background = Colors.grey.withValues(alpha: 0.2);
      borderColor = Colors.grey.withValues(alpha: 0.4);
      textColor = Colors.grey;
    } else if (isUsed) {
      background = theme.colorScheme.surface;
      borderColor = theme.colorScheme.outline.withValues(alpha: 0.2);
      textColor = theme.colorScheme.onSurface.withValues(alpha: 0.25);
    } else {
      background = AppTheme.primaryColor;
      borderColor = AppTheme.primaryColor;
      textColor = Colors.white;
    }

    final String poolStatus = isEliminated
        ? ', elendi'
        : isUsed
            ? ', kullanıldı'
            : '';
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Harf ${widget.tile.letter}$poolStatus',
      child: ScaleTransition(
      scale: _scaleController,
      child: GestureDetector(
        onTap: widget.enabled ? _handleTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: !isUsed && !isEliminated
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.tile.letter,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textColor,
              decoration: isEliminated ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    ),
    );
  }
}

// =============================================================================
// Çözüldü bottom sheet
// =============================================================================
class _SolvedSheet extends StatelessWidget {
  const _SolvedSheet({
    required this.puzzle,
    required this.stars,
    required this.score,
    required this.coinsEarned,
    required this.categoryComplete,
    required this.onNext,
    required this.onHome,
    this.isMix = false,
    this.isRepeat = false,
    this.newlyUnlockedAchievements = const <Achievement>[],
  });

  final Puzzle puzzle;
  final int stars;
  final int score;
  final int coinsEarned;
  final bool categoryComplete;
  final bool isMix;
  final bool isRepeat;
  final List<Achievement> newlyUnlockedAchievements;
  final VoidCallback onNext;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Karışık modda "kategori tamamlandı" mesajı anlamsız — başlıkları ona
    // göre uyarlıyoruz.
    final String title = categoryComplete
        ? (isMix ? '🏆 Tüm Bulmacaları Çözdün!' : '🏆 Kategori Tamamlandı!')
        : (isRepeat ? '✅ Doğru! (Tekrar)' : '🎉 Doğru!');
    final String buttonLabel = categoryComplete
        ? (isMix ? 'Ana Ekrana Dön' : 'Bölümlere Dön')
        : 'Sonraki Soru';
    final IconData buttonIcon = categoryComplete
        ? (isMix ? Icons.home_rounded : Icons.emoji_events_rounded)
        : Icons.arrow_forward_rounded;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                puzzle.answer,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isRepeat) ...<Widget>[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int s = 1; s <= 3; s++)
                      Icon(
                        s <= stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: s <= stars ? Colors.amber : Colors.grey,
                        size: 44,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              if (isRepeat)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Bu bulmacayı daha önce çözdün — ödül yok.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Text(
                        '+$score puan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '+$coinsEarned 💰',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '+1 Bulmaca Puanı',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              if (newlyUnlockedAchievements.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text('🏆', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            'Yeni başarım!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.amber[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final Achievement a in newlyUnlockedAchievements)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '🏆 ${a.name}  +${a.rewardCoins} 💰',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.amber[900],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onNext,
                icon: Icon(buttonIcon),
                label: Text(buttonLabel),
              ),
              if (!categoryComplete) ...<Widget>[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onHome,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Ana Menü'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

