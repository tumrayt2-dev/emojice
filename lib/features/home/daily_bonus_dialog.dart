import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/daily_bonus_service.dart';

/// Günlük giriş bonusu dialogu.
///
/// Hem bonusun verildiği (granted=true) hem de bilgilendirme amaçlı
/// (granted=false, "yarın tekrar gel") versiyonu destekler.
class DailyBonusDialog extends StatelessWidget {
  const DailyBonusDialog({super.key, required this.result});

  final DailyBonusResult result;

  static Future<void> show(BuildContext context, DailyBonusResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => DailyBonusDialog(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool granted = result.granted;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('🎁', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 10),
            Text(
              granted ? 'Günlük Bonus!' : 'Günün Bonusunu Aldın',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              granted
                  ? '${result.streakDay}. Gün — Tebrikler!'
                  : 'Yarın yeni bonus seni bekliyor.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 18),
            if (granted)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('💰', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Text(
                      '+${result.amount} coin',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            _StreakRow(currentStreak: result.streakDay),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Devam Et',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 7 günlük seri ilerleme satırı.
class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.currentStreak});

  final int currentStreak;

  static const List<int> _amounts = <int>[20, 30, 40, 50, 60, 80, 100];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (int i = 0; i < _amounts.length; i++)
          _StreakCell(
            day: i + 1,
            amount: _amounts[i],
            isCompleted: (i + 1) <= currentStreak,
            isCurrent: (i + 1) == currentStreak,
            theme: theme,
          ),
      ],
    );
  }
}

class _StreakCell extends StatelessWidget {
  const _StreakCell({
    required this.day,
    required this.amount,
    required this.isCompleted,
    required this.isCurrent,
    required this.theme,
  });

  final int day;
  final int amount;
  final bool isCompleted;
  final bool isCurrent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color background = isCurrent
        ? AppTheme.primaryColor
        : isCompleted
            ? AppTheme.primaryColor.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6);
    final Color textColor =
        isCurrent ? Colors.white : theme.colorScheme.onSurface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? AppTheme.primaryColor
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '+$amount',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
