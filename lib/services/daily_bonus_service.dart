import 'package:hive_flutter/hive_flutter.dart';

import 'coin_service.dart';

/// Günlük giriş bonusu sonucu.
class DailyBonusResult {
  const DailyBonusResult({
    required this.granted,
    required this.amount,
    required this.streakDay,
    required this.newCoinBalance,
  });

  /// Bu açılışta bonus verildi mi (gün değiştiyse `true`).
  final bool granted;

  /// Verilen coin miktarı (`granted=false` ise 0).
  final int amount;

  /// Mevcut ardışık gün sayısı (1..7 arası, 7'de döngü kalır).
  final int streakDay;

  /// Bonus eklendikten sonraki coin bakiyesi.
  final int newCoinBalance;
}

/// Günlük giriş bonusu servisi.
///
/// - Her takvim günü ilk açılışta bonus verir.
/// - Ardışık günlerde miktar artar: 1.gün +20, 2.gün +30, ... 7.gün +100.
/// - Bir gün atlanırsa seri başa döner (1.gün → +20).
/// - Aynı gün tekrar açılırsa bonus tekrar verilmez.
/// - Tüm durum Hive'da `daily_bonus_box` içinde saklanır.
class DailyBonusService {
  DailyBonusService({required CoinService coinService})
      : _coinService = coinService;

  final CoinService _coinService;

  static const String _boxName = 'daily_bonus_box';
  static const String _keyLastDate = 'last_claim_date';
  static const String _keyStreak = 'streak_day';

  /// Ardışık gün → coin tablosu.
  static const List<int> _bonusTable = <int>[20, 30, 40, 50, 60, 80, 100];

  Box<dynamic>? _box;

  Future<void> _ensureBox() async {
    if (_box != null && _box!.isOpen) {
      return;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  /// Belirli bir gün için verilecek bonus miktarı (1-tabanlı).
  static int bonusForDay(int day) {
    if (day < 1) {
      return _bonusTable.first;
    }
    if (day > _bonusTable.length) {
      return _bonusTable.last;
    }
    return _bonusTable[day - 1];
  }

  /// Bugün için bonusu (gerekirse) talep eder ve sonucu döndürür.
  Future<DailyBonusResult> claimIfAvailable() async {
    await _ensureBox();
    final String today = _todayKey();
    final String? lastDate = _box!.get(_keyLastDate) as String?;
    final int storedStreak = (_box!.get(_keyStreak) as int?) ?? 0;

    if (lastDate == today) {
      // Bugün zaten verilmiş.
      final int balance = await _coinService.getCoins();
      return DailyBonusResult(
        granted: false,
        amount: 0,
        streakDay: storedStreak == 0 ? 1 : storedStreak,
        newCoinBalance: balance,
      );
    }

    int newStreak;
    if (lastDate == null) {
      newStreak = 1;
    } else if (lastDate == _yesterdayKey()) {
      newStreak = storedStreak + 1;
      if (newStreak > _bonusTable.length) {
        newStreak = _bonusTable.length;
      }
    } else {
      // Seri kırıldı.
      newStreak = 1;
    }

    final int amount = bonusForDay(newStreak);
    final int newBalance = await _coinService.addCoins(amount);

    await _box!.put(_keyLastDate, today);
    await _box!.put(_keyStreak, newStreak);

    return DailyBonusResult(
      granted: true,
      amount: amount,
      streakDay: newStreak,
      newCoinBalance: newBalance,
    );
  }

  /// Mevcut seri gün sayısı (henüz claim edilmediyse 0).
  Future<int> currentStreak() async {
    await _ensureBox();
    return (_box!.get(_keyStreak) as int?) ?? 0;
  }

  String _todayKey() {
    final DateTime now = DateTime.now();
    return _formatDate(DateTime(now.year, now.month, now.day));
  }

  String _yesterdayKey() {
    final DateTime now = DateTime.now();
    final DateTime y = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    return _formatDate(y);
  }

  String _formatDate(DateTime d) {
    final String mm = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
