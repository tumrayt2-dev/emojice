import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Dev modu bayraklarının anlık durumu.
@immutable
class DevModeState {
  const DevModeState({
    required this.enabled,
    required this.disableAds,
    required this.fastSolvedDialog,
  });

  /// Dev modu genel açık mı?
  final bool enabled;

  /// Reklam servisini no-op yap. Rewarded otomatik success döner ki
  /// kategori-açma akışı denenebilsin; interstitial tamamen atlanır.
  final bool disableAds;

  /// Solved dialog gecikmesini 1500ms yerine 100ms yap.
  final bool fastSolvedDialog;

  static const DevModeState off = DevModeState(
    enabled: false,
    disableAds: false,
    fastSolvedDialog: false,
  );

  DevModeState copyWith({
    bool? enabled,
    bool? disableAds,
    bool? fastSolvedDialog,
  }) {
    return DevModeState(
      enabled: enabled ?? this.enabled,
      disableAds: disableAds ?? this.disableAds,
      fastSolvedDialog: fastSolvedDialog ?? this.fastSolvedDialog,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'disableAds': disableAds,
        'fastSolvedDialog': fastSolvedDialog,
      };

  factory DevModeState.fromJson(Map<String, dynamic> json) {
    return DevModeState(
      enabled: json['enabled'] as bool? ?? false,
      disableAds: json['disableAds'] as bool? ?? false,
      fastSolvedDialog: json['fastSolvedDialog'] as bool? ?? false,
    );
  }
}

/// Hive üzerinde dev mode bayraklarını saklayan servis.
class DevModeService {
  DevModeService();

  static const String _boxName = 'dev_mode_box';
  static const String _key = 'state';

  Box<dynamic>? _box;
  DevModeState _cache = DevModeState.off;
  bool _loaded = false;

  Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      return;
    }
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Future<DevModeState> load() async {
    if (_loaded) return _cache;
    await init();
    final dynamic raw = _box!.get(_key);
    if (raw is Map) {
      _cache = DevModeState.fromJson(_coerceMap(raw));
    } else {
      _cache = DevModeState.off;
    }
    _loaded = true;
    return _cache;
  }

  /// Senkron erişim — `load()` önceden çağrılmış olmalıdır.
  DevModeState get current => _cache;

  Future<DevModeState> save(DevModeState state) async {
    await init();
    _cache = state;
    _loaded = true;
    await _box!.put(_key, state.toJson());
    return state;
  }

  /// Dev modu aç/kapat. Kapatılınca tüm bayraklar sıfırlanır.
  Future<DevModeState> setEnabled(bool enabled) async {
    final DevModeState next =
        enabled ? _cache.copyWith(enabled: true) : DevModeState.off;
    return save(next);
  }

  Future<DevModeState> setDisableAds(bool v) =>
      save(_cache.copyWith(disableAds: v));

  Future<DevModeState> setFastSolvedDialog(bool v) =>
      save(_cache.copyWith(fastSolvedDialog: v));

  Map<String, dynamic> _coerceMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    final Map<dynamic, dynamic> m = raw as Map<dynamic, dynamic>;
    return <String, dynamic>{
      for (final dynamic k in m.keys) k.toString(): m[k],
    };
  }
}
