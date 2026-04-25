import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/player_progress.dart';
import '../../providers/service_providers.dart';
import '../../services/ad_service.dart';
import '../../services/category_service.dart';
import '../../services/progress_service.dart';
import '../../services/purchase_service.dart';
import '../../services/unlock_service.dart';

/// Tüm kategorileri ızgara şeklinde gösteren ekran.
///
/// Üstte tier ilerleme barı + altında 5 tier listesi (expandable).
/// Kilitli kategoriler için bottom sheet ile şart + reklamla açma seçeneği.
class CategorySelectionScreen extends ConsumerWidget {
  const CategorySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PuzzleCategory>> categoriesAsync =
        ref.watch(_categoriesFutureProvider);
    final AsyncValue<PlayerProgress> progressAsync =
        ref.watch(playerProgressProvider);

    final int coins = progressAsync.maybeWhen<int>(
      data: (PlayerProgress p) => p.coins,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Mağaza',
            icon: const Icon(Icons.shopping_bag_rounded),
            onPressed: () => context.go('/store'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CoinBadge(coins: coins),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Kategoriler yüklenemedi.\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (List<PuzzleCategory> categories) {
          final PlayerProgress progress =
              progressAsync.maybeWhen<PlayerProgress>(
            data: (PlayerProgress p) => p,
            orElse: PlayerProgress.initial,
          );
          final UnlockService unlockService =
              ref.watch(unlockServiceProvider);
          return Column(
            children: <Widget>[
              _TierProgressHeader(
                categories: categories,
                progress: progress,
                unlockService: unlockService,
              ),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (BuildContext context, int index) {
                    final PuzzleCategory cat = categories[index];
                    final int solved = progress.solvedCountFor(cat.id);
                    final UnlockStatus status = unlockService.statusFor(
                      category: cat,
                      progress: progress,
                      allCategories: categories,
                    );
                    return _CategoryCard(
                      category: cat,
                      solvedCount: solved,
                      unlockStatus: status,
                      onTap: () {
                        if (status.isUnlocked) {
                          context.go('/levels/${cat.id}');
                        } else {
                          _showLockedSheet(context, cat, status);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLockedSheet(
    BuildContext context,
    PuzzleCategory category,
    UnlockStatus status,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (BuildContext ctx) {
        return _LockedBottomSheet(category: category, status: status);
      },
    );
  }
}

/// Kategori listesini servis üzerinden yükleyen provider.
final FutureProvider<List<PuzzleCategory>> _categoriesFutureProvider =
    FutureProvider<List<PuzzleCategory>>((Ref ref) async {
  final CategoryService service = ref.watch(categoryServiceProvider);
  return service.loadAll();
});

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.monetization_on_rounded,
            color: AppTheme.secondaryColor,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            coins.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Üstteki tier ilerleme barı + expandable 5 tier listesi.
class _TierProgressHeader extends StatefulWidget {
  const _TierProgressHeader({
    required this.categories,
    required this.progress,
    required this.unlockService,
  });

  final List<PuzzleCategory> categories;
  final PlayerProgress progress;
  final UnlockService unlockService;

  @override
  State<_TierProgressHeader> createState() => _TierProgressHeaderState();
}

class _TierProgressHeaderState extends State<_TierProgressHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int totalSolved = widget.progress.totalSolvedCount;
    final int adPoints = widget.progress.totalAdPoints;
    final int totalPoints = totalSolved + adPoints;

    // Tier sınırları kategorilerden okunur, sıralı eşsiz değerler.
    final List<int> tiers = <int>{
      for (final PuzzleCategory c in widget.categories)
        if (c.unlock != null) c.unlock!.tierValue,
    }.toList()
      ..sort();

    final int nextTier = tiers.firstWhere(
      (int t) => t > totalPoints,
      orElse: () => totalPoints == 0 ? (tiers.isNotEmpty ? tiers.first : 0) : 0,
    );
    final int currentTierBase = tiers
        .where((int t) => t <= totalPoints)
        .fold<int>(0, (int prev, int v) => v > prev ? v : prev);
    final int gap = nextTier > 0 ? nextTier - totalPoints : 0;
    final double ratio = nextTier > 0
        ? ((totalPoints - currentTierBase) /
                (nextTier - currentTierBase))
            .clamp(0.0, 1.0)
        : 1.0;

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.emoji_events_rounded,
                      color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bulmaca Puanı: $totalPoints'
                        '${adPoints > 0 ? " (📚$totalSolved + 📺$adPoints)" : ""}',
                        maxLines: 1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                nextTier > 0
                    ? 'Sıradaki tier: $nextTier puan ($gap kaldı)'
                    : 'Tüm tier\'lar açık 🎉',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (_expanded) ...<Widget>[
                const SizedBox(height: 12),
                _TierList(
                  categories: widget.categories,
                  progress: widget.progress,
                  unlockService: widget.unlockService,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 5 tier listesi: her tier için durum + içerdiği kategoriler + zincir notları.
class _TierList extends StatelessWidget {
  const _TierList({
    required this.categories,
    required this.progress,
    required this.unlockService,
  });

  final List<PuzzleCategory> categories;
  final PlayerProgress progress;
  final UnlockService unlockService;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int totalPoints =
        progress.totalSolvedCount + progress.totalAdPoints;

    // Kategorileri tier eşiğine göre grupla.
    final Map<int, List<PuzzleCategory>> grouped = <int, List<PuzzleCategory>>{};
    final List<PuzzleCategory> openCats = <PuzzleCategory>[];
    for (final PuzzleCategory c in categories) {
      if (c.unlock == null) {
        openCats.add(c);
      } else {
        grouped.putIfAbsent(c.unlock!.tierValue, () => <PuzzleCategory>[]).add(c);
      }
    }
    final List<int> tierValues = grouped.keys.toList()..sort();

    final List<Widget> children = <Widget>[];
    if (openCats.isNotEmpty) {
      children.add(_tierSection(
        theme,
        title: '🟢 Başlangıç (Açık)',
        categories: openCats,
        unlocked: true,
      ));
    }
    for (final int tv in tierValues) {
      final List<PuzzleCategory> cats = grouped[tv]!;
      final bool tierReached = totalPoints >= tv;
      final String emoji = tierReached ? '🟢' : (totalPoints * 2 >= tv ? '🟡' : '🔒');
      final String suffix = tierReached
          ? 'Açık'
          : '$tv puan (${tv - totalPoints} kaldı)';
      children.add(_tierSection(
        theme,
        title: '$emoji Tier $tv — $suffix',
        categories: cats,
        unlocked: tierReached,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          children[i],
          if (i != children.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _tierSection(
    ThemeData theme, {
    required String title,
    required List<PuzzleCategory> categories,
    required bool unlocked,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: unlocked ? 0.5 : 0.25,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          for (final PuzzleCategory c in categories)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: _categoryRow(theme, c),
            ),
        ],
      ),
    );
  }

  Widget _categoryRow(ThemeData theme, PuzzleCategory c) {
    final UnlockStatus s = unlockService.statusFor(
      category: c,
      progress: progress,
      allCategories: categories,
    );
    String chainNote = '';
    if (c.unlock?.type == UnlockType.chain &&
        c.unlock?.chainTarget != null &&
        c.unlock?.chainValue != null) {
      final String chainName = s.chainCategoryName ?? c.unlock!.chainTarget!;
      chainNote =
          ' (+ $chainName: ${s.chainProgress ?? 0}/${c.unlock!.chainValue})';
    }
    final IconData icon =
        s.isUnlocked ? Icons.check_circle_rounded : Icons.lock_rounded;
    final Color color =
        s.isUnlocked ? Colors.green : theme.colorScheme.onSurfaceVariant;
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(c.icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${c.name}$chainNote',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.solvedCount,
    required this.unlockStatus,
    required this.onTap,
  });

  final PuzzleCategory category;
  final int solvedCount;
  final UnlockStatus unlockStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int total = category.puzzleCount;
    final double ratio = total > 0 ? (solvedCount / total).clamp(0, 1) : 0;
    final bool isComplete = total > 0 && solvedCount >= total;
    final bool isLocked = !unlockStatus.isUnlocked;

    final String semanticsLabel = isLocked
        ? 'Kategori: ${category.name}, kilitli. ${unlockStatus.reason}'
        : 'Kategori: ${category.name}, $solvedCount/$total çözüldü';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: isLocked ? 0.35 : 0.7,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary
                    .withValues(alpha: isLocked ? 0.12 : 0.25),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Opacity(
                    opacity: isLocked ? 0.35 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Center(
                            child: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 56),
                            ),
                          ),
                        ),
                        Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: ratio.toDouble(),
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$solvedCount / $total',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isComplete && !isLocked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                if (isLocked)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kilitli kategori detay sheet'i — şart açıklaması + reklamla açma.
class _LockedBottomSheet extends ConsumerStatefulWidget {
  const _LockedBottomSheet({required this.category, required this.status});

  final PuzzleCategory category;
  final UnlockStatus status;

  @override
  ConsumerState<_LockedBottomSheet> createState() => _LockedBottomSheetState();
}

class _LockedBottomSheetState extends ConsumerState<_LockedBottomSheet> {
  bool _watchingAd = false;
  Duration? _cooldownRemaining;
  bool _checkedCooldown = false;

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  Future<void> _checkCooldown() async {
    final PurchaseService purchaseService = ref.read(purchaseServiceProvider);
    final ProgressService progressService = ref.read(progressServiceProvider);
    final bool noAds = await purchaseService.isAdsRemoved();
    final ({bool blocked, Duration remaining}) cd =
        await progressService.tierAdCooldown(noAdsActive: noAds);
    if (!mounted) return;
    setState(() {
      _cooldownRemaining = cd.blocked ? cd.remaining : null;
      _checkedCooldown = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UnlockStatus s = widget.status;

    final double tierRatio = s.tierTarget > 0
        ? (s.effectiveProgress / s.tierTarget).clamp(0, 1).toDouble()
        : 0;
    final int gap = (s.tierTarget - s.effectiveProgress)
        .clamp(0, s.tierTarget)
        .toInt();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(widget.category.icon,
                      style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.category.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.lock_rounded, color: Colors.amber),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Bu kategoriyi açmak için',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.emoji_events_rounded,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${s.tierTarget} Bulmaca Puanı',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: tierRatio,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Şu an: ${s.effectiveProgress} / ${s.tierTarget}'
                      '${gap > 0 ? "  ·  $gap puan kaldı" : ""}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (s.chainTarget != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        '+ ${s.chainCategoryName ?? "Bağlı kategori"}: '
                        '${s.chainProgress ?? 0} / ${s.chainTarget} çözüm gerekli',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (s.adsRemaining > 0) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Divider(color: theme.dividerColor)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'VEYA',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.dividerColor)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Reklam İzleyerek Hızlandır',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Her reklam = +5 Bulmaca Puanı  ·  '
                  '${s.adsRemaining} reklam yeterli',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _watchingAd
                          ? 'Yükleniyor...'
                          : (_cooldownRemaining != null
                              ? 'Bekle: ${_formatDuration(_cooldownRemaining!)}'
                              : 'Reklam İzle (+5 Bulmaca Puanı)'),
                    ),
                    onPressed: (_watchingAd ||
                            _cooldownRemaining != null ||
                            !_checkedCooldown)
                        ? null
                        : _onWatchAd,
                  ),
                ),
                if (_cooldownRemaining != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Premium pakette saatte 1 reklam izleyebilirsin.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ] else ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.reason.isNotEmpty
                        ? s.reason
                        : 'Şartlar tamamlandı, kategori birazdan açılacak.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final int mins = d.inMinutes;
    if (mins >= 60) {
      return '${mins ~/ 60}s ${mins % 60}d';
    }
    if (mins > 0) {
      return '${mins}d';
    }
    return '${d.inSeconds}s';
  }

  Future<void> _onWatchAd() async {
    setState(() {
      _watchingAd = true;
    });
    final AdService adService = ref.read(adServiceProvider);
    final ProgressService progressService =
        ref.read(progressServiceProvider);
    final PurchaseService purchaseService = ref.read(purchaseServiceProvider);
    try {
      // Saatlik limit re-check (yarış olmasın).
      final bool noAds = await purchaseService.isAdsRemoved();
      final ({bool blocked, Duration remaining}) cd =
          await progressService.tierAdCooldown(noAdsActive: noAds);
      if (cd.blocked) {
        if (mounted) {
          setState(() {
            _watchingAd = false;
            _cooldownRemaining = cd.remaining;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saatte 1 reklam — ${_formatDuration(cd.remaining)} sonra dene',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final bool rewarded = await adService.showRewardedAd(context);
      if (!rewarded) {
        if (mounted) {
          setState(() {
            _watchingAd = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reklam tamamlanmadı')),
          );
        }
        return;
      }
      await progressService.incrementUnlockAd(widget.category.id);
      ref.invalidate(playerProgressProvider);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _watchingAd = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }
}
