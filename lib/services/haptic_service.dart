import 'package:flutter/services.dart';

/// Tüm haptik (titreşim) geri bildirimlerini tek noktadan yönetir.
///
/// Flutter'in built-in [HapticFeedback] API'sini kullanır — ekstra paket
/// gerektirmez. Cihaz desteklemiyorsa sessizce no-op olur.
class HapticService {
  const HapticService();

  /// Harf seçimi: kısa, hafif titreşim.
  Future<void> letterTap() async {
    await HapticFeedback.selectionClick();
  }

  /// Doğru cevap: orta + hafif çift titreşim (mutlu his).
  Future<void> correctAnswer() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    await HapticFeedback.lightImpact();
  }

  /// Yanlış cevap: uzun (heavy) titreşim.
  Future<void> wrongAnswer() async {
    await HapticFeedback.heavyImpact();
  }

  /// İpucu kullanımı: tek hafif titreşim.
  Future<void> hintUsed() async {
    await HapticFeedback.lightImpact();
  }

  /// Seviye/kategori tamamlama: kademeli pattern titreşim.
  Future<void> levelComplete() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.heavyImpact();
  }
}
