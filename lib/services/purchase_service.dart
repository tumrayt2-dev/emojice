import 'package:hive_flutter/hive_flutter.dart';

/// Uygulama içi satın alma servisi.
///
/// Plan gereği şu an MOCK çalışır: gerçek `in_app_purchase` store akışı
/// yerine satın alma durumlarını Hive'a yazar. Üretime alınırken bu sınıfın
/// içi gerçek `InAppPurchase.instance` ile değiştirilebilir; arayüz aynı
/// kalır.
class PurchaseService {
  PurchaseService();

  // ---------- Ürün ID sabitleri ----------
  static const String productPremiumAll = 'emoji_premium_all';
  static const String productPremiumSeries = 'emoji_premium_series';
  static const String productPremiumSongs = 'emoji_premium_songs';
  static const String productPremiumCountries = 'emoji_premium_countries';
  static const String productCoin500 = 'emoji_coin_500';
  static const String productCoin1500 = 'emoji_coin_1500';
  static const String productNoAds = 'emoji_no_ads';

  /// Tüm bilinen ürün id'leri.
  static const List<String> allProductIds = <String>[
    productPremiumAll,
    productPremiumSeries,
    productPremiumSongs,
    productPremiumCountries,
    productCoin500,
    productCoin1500,
    productNoAds,
  ];

  /// Coin paketlerinin verdiği coin miktarı.
  static const Map<String, int> coinAmounts = <String, int>{
    productCoin500: 500,
    productCoin1500: 1500,
  };

  /// "Reklamsız" paketinin satın alındığında bir kez verdiği bonus jeton.
  /// Pakete cazibe katmak için (yalnız reklam kaldırma değil + jeton bonusu).
  static const int noAdsBonusCoins = 500;

  /// CategoryId → onu açan tekil ürün id eşlemesi.
  static const Map<String, String> categoryProductMap = <String, String>{
    'series': productPremiumSeries,
    'songs': productPremiumSongs,
    'countries': productPremiumCountries,
  };

  static const String _boxName = 'purchases_box';
  static const String _purchasedKey = 'purchased_products';

  Box<dynamic>? _box;

  /// Hive kutusunu açar; [Hive.initFlutter] önceden çağrılmış olmalıdır.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      return;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  /// Şu ana kadar satın alınmış (mock) ürün id'lerinin kümesi.
  Future<Set<String>> _loadPurchased() async {
    await init();
    final dynamic raw = _box!.get(_purchasedKey);
    if (raw == null) {
      return <String>{};
    }
    if (raw is List) {
      return raw.map<String>((dynamic e) => e.toString()).toSet();
    }
    return <String>{};
  }

  Future<void> _savePurchased(Set<String> set) async {
    await init();
    await _box!.put(_purchasedKey, set.toList());
  }

  /// Bir ürün satın alındı mı? "Tümü" paketi premium kategorileri kapsar.
  Future<bool> isPurchased(String productId) async {
    final Set<String> set = await _loadPurchased();
    if (set.contains(productId)) {
      return true;
    }
    // "Tümü" paketi premium kategori paketlerini de kapsasın.
    if (set.contains(productPremiumAll) &&
        (productId == productPremiumSeries ||
            productId == productPremiumSongs ||
            productId == productPremiumCountries)) {
      return true;
    }
    return false;
  }

  /// Belirli bir kategorinin (kalıcı) açık olup olmadığını döndürür.
  Future<bool> isCategoryUnlocked(String categoryId) async {
    final String? productId = categoryProductMap[categoryId];
    if (productId == null) {
      return false;
    }
    return isPurchased(productId);
  }

  /// "Reklam Kaldır" satın alındı mı?
  Future<bool> isAdsRemoved() => isPurchased(productNoAds);

  /// Tüm satın alınmış ürünleri döndürür.
  Future<Set<String>> getPurchased() => _loadPurchased();

  /// MOCK satın alma — gerçek store yerine doğrudan kayıt.
  /// Satın alma başarılıysa `true` döner.
  Future<bool> buyProduct(String productId) async {
    if (!allProductIds.contains(productId)) {
      return false;
    }
    final Set<String> set = await _loadPurchased();
    // Coin paketleri "consumable"; her satın alımda coin eklenir,
    // kalıcı satın alma listesine eklenmez.
    if (productId == productCoin500 || productId == productCoin1500) {
      // Coin paketinin coin eklemesi çağıran tarafın sorumluluğunda
      // (CoinService) — burada sadece "satın alma başarılı" olarak işaretle.
      return true;
    }
    set.add(productId);
    await _savePurchased(set);
    return true;
  }

  /// MOCK geri yükleme — Hive'daki kayıtlı durumu döndürür.
  Future<Set<String>> restorePurchases() async {
    return _loadPurchased();
  }

  /// Test/geliştirme amaçlı tüm satın almaları siler.
  Future<void> clearAll() async {
    await init();
    await _box!.delete(_purchasedKey);
  }
}
