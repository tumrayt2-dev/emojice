import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/player_progress.dart';
import '../../providers/service_providers.dart';
import '../../services/achievement_service.dart';

/// Tüm başarımları listeleyen dialog.
class AchievementsDialog extends ConsumerStatefulWidget {
  const AchievementsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (BuildContext ctx) => const AchievementsDialog(),
    );
  }

  @override
  ConsumerState<AchievementsDialog> createState() => _AchievementsDialogState();
}

class _AchievementsDialogState extends ConsumerState<AchievementsDialog> {
  late Future<List<Achievement>> _achievementsFuture;
  late Future<PlayerProgress> _progressFuture;

  @override
  void initState() {
    super.initState();
    _achievementsFuture =
        ref.read(achievementServiceProvider).allAchievements();
    _progressFuture = ref.read(progressServiceProvider).load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size screen = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screen.height * 0.82,
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text('🏆', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Başarımlar',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Achievement>>(
                  future: _achievementsFuture,
                  builder: (BuildContext context,
                      AsyncSnapshot<List<Achievement>> snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final List<Achievement> list = snap.data!;
                    return FutureBuilder<PlayerProgress>(
                      future: _progressFuture,
                      builder: (BuildContext context,
                          AsyncSnapshot<PlayerProgress> ps) {
                        if (!ps.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final PlayerProgress progress = ps.data!;
                        return ListView.separated(
                          itemCount: list.length,
                          separatorBuilder:
                              (BuildContext _, int _) =>
                                  const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final Achievement a = list[index];
                            final bool unlocked =
                                progress.isAchievementUnlocked(a.id);
                            return _AchievementRow(
                              achievement: a,
                              unlocked: unlocked,
                              progressFuture: ref
                                  .read(achievementServiceProvider)
                                  .progressFor(a),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.achievement,
    required this.unlocked,
    required this.progressFuture,
  });

  final Achievement achievement;
  final bool unlocked;
  final Future<({int current, int target})> progressFuture;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = unlocked ? Colors.green : AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: unlocked
            ? Colors.green.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Text(
                achievement.icon,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        achievement.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '+${achievement.rewardCoins} 💰',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<({int current, int target})>(
                  future: progressFuture,
                  builder: (BuildContext context,
                      AsyncSnapshot<({int current, int target})> snap) {
                    final int current = snap.data?.current ?? 0;
                    final int target = snap.data?.target ?? 1;
                    final double ratio = target <= 0
                        ? 0
                        : (current / target).clamp(0.0, 1.0);
                    if (unlocked) {
                      return Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Açıldı · Alındı',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.green[800],
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: theme
                                .colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$current / $target',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
