import 'package:hive_flutter/hive_flutter.dart';

/// İlk açılış (onboarding) durumunu Hive üzerinde tutan servis.
class OnboardingService {
  OnboardingService();

  static const String _boxName = 'onboarding_box';
  static const String _seenKey = 'seen_v1';

  Box<dynamic>? _box;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      return;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  /// Onboarding'i daha önce görmüş mü?
  Future<bool> hasSeen() async {
    await init();
    return _box!.get(_seenKey) == true;
  }

  /// Onboarding'i "görüldü" olarak işaretle.
  Future<void> markSeen() async {
    await init();
    await _box!.put(_seenKey, true);
  }

  /// Test/dev: onboarding'i sıfırla — bir sonraki açılışta tekrar gösterilir.
  Future<void> reset() async {
    await init();
    await _box!.delete(_seenKey);
  }
}
