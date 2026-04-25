import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/category.dart';
import '../../models/player_progress.dart';
import '../../models/puzzle.dart';
import '../../providers/service_providers.dart';
import '../../services/category_service.dart';
import '../../services/puzzle_service.dart';

/// Zorluk → renk eşlemesi (border için).
const Color _kDifficultyEasy = Color(0xFF4CAF50);
const Color _kDifficultyMedium = Color(0xFFFF9800);
const Color _kDifficultyHard = Color(0xFFE53935);

/// Bir kategori için tüm bulmacaların listesini gösterir. Kilit yoktur;
/// kullanıcı istediği sırada oynayabilir.
class LevelSelectionScreen extends ConsumerWidget {
  const LevelSelectionScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<_LevelData> dataAsync =
        ref.watch(_levelDataProvider(categoryId));
    final AsyncValue<PlayerProgress> progressAsync =
        ref.watch(playerProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bölümler'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/categories'),
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Bölümler yüklenemedi.\n$err',
                textAlign: TextAlign.center),
          ),
        ),
        data: (_LevelData data) {
          final PlayerProgress progress =
              progressAsync.maybeWhen<PlayerProgress>(
            data: (PlayerProgress p) => p,
            orElse: PlayerProgress.initial,
          );
          return _PuzzleList(
            category: data.category,
            puzzles: data.puzzles,
            progress: progress,
          );
        },
      ),
    );
  }
}

class _LevelData {
  const _LevelData({required this.category, required this.puzzles});

  final PuzzleCategory category;
  final List<Puzzle> puzzles;
}

/// Kategori bilgisi + sıralı puzzle listesini yükleyen provider.
final AutoDisposeFutureProviderFamily<_LevelData, String> _levelDataProvider =
    FutureProvider.autoDispose.family<_LevelData, String>(
        (Ref ref, String categoryId) async {
  final PuzzleService puzzleService = ref.watch(puzzleServiceProvider);
  final CategoryService categoryService = ref.watch(categoryServiceProvider);

  final List<Puzzle> puzzles = await puzzleService.byCategory(categoryId);
  final List<PuzzleCategory> all = await categoryService.loadAll();
  final PuzzleCategory category = all.firstWhere(
    (PuzzleCategory c) => c.id == categoryId,
    orElse: () => PuzzleCategory(
      id: categoryId,
      name: categoryId,
      icon: '❓',
      puzzleCount: puzzles.length,
      isPremium: false,
    ),
  );
  return _LevelData(category: category, puzzles: puzzles);
});

class _PuzzleList extends StatelessWidget {
  const _PuzzleList({
    required this.category,
    required this.puzzles,
    required this.progress,
  });

  final PuzzleCategory category;
  final List<Puzzle> puzzles;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final int solved = <Puzzle>[
      for (final Puzzle p in puzzles)
        if (progress.isSolved(category.id, p.id)) p,
    ].length;
    final double ratio = puzzles.isEmpty ? 0 : solved / puzzles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$solved / ${puzzles.length} çözüldü',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              20 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: puzzles.length,
            itemBuilder: (BuildContext context, int index) {
              final Puzzle puzzle = puzzles[index];
              final bool isSolved =
                  progress.isSolved(category.id, puzzle.id);
              final int stars =
                  progress.starsFor(category.id, puzzle.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PuzzleCard(
                  puzzle: puzzle,
                  isSolved: isSolved,
                  stars: stars,
                  onTap: () =>
                      context.go('/game/${category.id}/${puzzle.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tek satırlık bulmaca kartı — sol: emoji, orta: meta, sağ: durum.
class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.puzzle,
    required this.isSolved,
    required this.stars,
    required this.onTap,
  });

  final Puzzle puzzle;
  final bool isSolved;
  final int stars;
  final VoidCallback onTap;

  Color _difficultyColor() {
    switch (puzzle.difficulty) {
      case 1:
        return _kDifficultyEasy;
      case 2:
        return _kDifficultyMedium;
      case 3:
        return _kDifficultyHard;
      default:
        return _kDifficultyMedium;
    }
  }

  String _difficultyLabel() {
    switch (puzzle.difficulty) {
      case 1:
        return 'Kolay';
      case 2:
        return 'Orta';
      case 3:
        return 'Zor';
      default:
        return 'Orta';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color borderColor = _difficultyColor();

    final String semanticsLabel = isSolved
        ? 'Bulmaca, ${puzzle.letterCount} harf, ${_difficultyLabel()}, çözüldü, $stars yıldız'
        : 'Bulmaca, ${puzzle.letterCount} harf, ${_difficultyLabel()}';

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
              color: isSolved
                  ? Colors.green.withValues(alpha: 0.08)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor.withValues(alpha: 0.8),
                width: 2,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: <Widget>[
                  // Sol: emoji
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          puzzle.emojis,
                          style: const TextStyle(fontSize: 36),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Orta: meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '${puzzle.letterCount} harf · ${_difficultyLabel()}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: borderColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _difficultyLabel(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: borderColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sağ: durum (çözülmüş: check + yıldız / çözülmemiş: ok)
                  if (isSolved)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (int s = 1; s <= 3; s++)
                              Icon(
                                s <= stars
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color:
                                    s <= stars ? Colors.amber : Colors.grey,
                                size: 16,
                              ),
                          ],
                        ),
                      ],
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
