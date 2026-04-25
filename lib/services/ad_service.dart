import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'dev_mode_service.dart';
import 'purchase_service.dart';

/// Reklam servisinin durumlarını dışa bildirmek için kullanılan tip.
typedef AdEventCallback = void Function();

/// AdMob entegrasyonu — banner, interstitial ve rewarded reklamları yönetir.
///
/// Plan gereği:
///   * Test ID'leri kullanılır (Google'ın resmi sample id'leri).
///   * Interstitial: her 4 çözülen sorudan sonra gösterilir.
///   * Rewarded: kullanıcı izlediğinde +50 coin verir.
///   * "Reklam Kaldır" satın alındıysa interstitial gösterilmez.
///   * Rewarded yüklenemezse mock fallback (3 sn dialog) kullanılır.
class AdService {
  AdService({
    required PurchaseService purchaseService,
    DevModeService? devModeService,
  })  : _purchaseService = purchaseService,
        _devModeService = devModeService;

  final PurchaseService _purchaseService;
  final DevModeService? _devModeService;

  /// Dev modda "reklamlar kapalı" toggle'ı açıksa rewarded reklam akışı
  /// anında başarılı kabul edilir, interstitial atlanır.
  bool get _devDisableAds =>
      _devModeService?.current.enabled == true &&
      _devModeService!.current.disableAds;

  /// Çözülen soru sayısının kaç adımda bir interstitial tetikleyeceği.
  static const int interstitialFrequency = 4;

  // ---------- Reklam birim id'leri ----------
  // Android: Emojice production AdMob ad units.
  // iOS: henüz iOS yayınlanmadığı için Google sample test id'leri kullanılır.
  static const String _androidBannerId =
      'ca-app-pub-8438407620610676/5126471265';
  static const String _iosBannerTestId =
      'ca-app-pub-3940256099942544/2934735716';

  static const String _androidInterstitialId =
      'ca-app-pub-8438407620610676/3054841691';
  static const String _iosInterstitialTestId =
      'ca-app-pub-3940256099942544/4411468910';

  static const String _androidRewardedId =
      'ca-app-pub-8438407620610676/9153346187';
  static const String _iosRewardedTestId =
      'ca-app-pub-3940256099942544/1712485313';

  bool _initialized = false;
  bool _initializing = false;

  InterstitialAd? _interstitialAd;
  bool _loadingInterstitial = false;

  RewardedAd? _rewardedAd;
  bool _loadingRewarded = false;

  int _solvedCounter = 0;

  /// Banner reklam birim id (platforma göre).
  String get bannerAdUnitId {
    if (kIsWeb) {
      return _androidBannerId;
    }
    if (Platform.isIOS) {
      return _iosBannerTestId;
    }
    return _androidBannerId;
  }

  String get _interstitialAdUnitId {
    if (kIsWeb) {
      return _androidInterstitialId;
    }
    if (Platform.isIOS) {
      return _iosInterstitialTestId;
    }
    return _androidInterstitialId;
  }

  String get _rewardedAdUnitId {
    if (kIsWeb) {
      return _androidRewardedId;
    }
    if (Platform.isIOS) {
      return _iosRewardedTestId;
    }
    return _androidRewardedId;
  }

  /// Mobil reklam SDK'sını başlatır. Web/desktop'ta sessizce no-op.
  Future<void> init() async {
    if (_initialized || _initializing) {
      return;
    }
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _initialized = true;
      return;
    }
    _initializing = true;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      // Hazırda bir interstitial ve rewarded yüklemeye başla.
      unawaited(_loadInterstitial());
      unawaited(_loadRewarded());
    } catch (e) {
      debugPrint('AdService init error: $e');
    } finally {
      _initializing = false;
    }
  }

  bool get _supportsAds {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  // ---------------------------------------------------------------------------
  // Interstitial
  // ---------------------------------------------------------------------------

  Future<void> _loadInterstitial() async {
    if (!_supportsAds || _loadingInterstitial || _interstitialAd != null) {
      return;
    }
    _loadingInterstitial = true;
    final Completer<void> completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _loadingInterstitial = false;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Interstitial load failed: $error');
          _interstitialAd = null;
          _loadingInterstitial = false;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );
    return completer.future;
  }

  /// Bir soru daha çözüldü. Eşik dolduysa interstitial gösterir.
  /// Reklam kaldırma satın alındıysa hiçbir şey yapmaz.
  Future<void> notifyPuzzleSolved() async {
    if (!_supportsAds) {
      return;
    }
    if (_devDisableAds) {
      return;
    }
    if (await _purchaseService.isAdsRemoved()) {
      return;
    }
    _solvedCounter++;
    if (_solvedCounter % interstitialFrequency != 0) {
      return;
    }
    await _showInterstitial();
  }

  Future<void> _showInterstitial() async {
    if (!_supportsAds) {
      return;
    }
    if (_interstitialAd == null) {
      // Tetiklendiğinde elimizde reklam yoksa bir tane yüklemeye çalış.
      await _loadInterstitial();
    }
    final InterstitialAd? ad = _interstitialAd;
    if (ad == null) {
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _interstitialAd = null;
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent:
          (InterstitialAd ad, AdError error) {
        debugPrint('Interstitial show failed: $error');
        ad.dispose();
        _interstitialAd = null;
        unawaited(_loadInterstitial());
      },
    );
    await ad.show();
  }

  // ---------------------------------------------------------------------------
  // Rewarded
  // ---------------------------------------------------------------------------

  Future<void> _loadRewarded() async {
    if (!_supportsAds || _loadingRewarded || _rewardedAd != null) {
      return;
    }
    _loadingRewarded = true;
    final Completer<void> completer = Completer<void>();
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _loadingRewarded = false;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('Rewarded load failed: $error');
          _rewardedAd = null;
          _loadingRewarded = false;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );
    return completer.future;
  }

  /// Rewarded reklam gösterir. Reklam izlendiyse `true` döner.
  ///
  /// Gerçek AdMob reklamı yüklenemediyse mock fallback olarak 3 saniyelik
  /// "Reklam izleniyor..." dialog'u gösterilir ve `true` döndürülür.
  Future<bool> showRewardedAd(BuildContext context) async {
    if (_devDisableAds) {
      // Dev modda reklamlar kapalı — anında başarılı say.
      return true;
    }
    if (!_supportsAds) {
      return _showMockRewardedAd(context);
    }
    if (_rewardedAd == null) {
      await _loadRewarded();
    }
    if (!context.mounted) {
      return false;
    }
    final RewardedAd? ad = _rewardedAd;
    if (ad == null) {
      // Yüklenemediyse mock fallback.
      return _showMockRewardedAd(context);
    }

    final Completer<bool> completer = Completer<bool>();
    bool earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        unawaited(_loadRewarded());
        if (!completer.isCompleted) {
          completer.complete(earned);
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('Rewarded show failed: $error');
        ad.dispose();
        _rewardedAd = null;
        unawaited(_loadRewarded());
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    await ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        earned = true;
      },
    );

    return completer.future;
  }

  Future<bool> _showMockRewardedAd(BuildContext context) async {
    if (!context.mounted) {
      return false;
    }
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return const AlertDialog(
          content: SizedBox(
            height: 80,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Reklam izleniyor...'),
                ],
              ),
            ),
          ),
        );
      },
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    if (navigator.mounted) {
      navigator.pop();
    }
    return true;
  }

  /// Test/geliştirme: reklam sayacını sıfırla.
  void resetCounter() {
    _solvedCounter = 0;
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
