import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/service_providers.dart';
import '../../services/dev_mode_service.dart';

/// Dev modu paneli. Versiyon yazısına 5 kez tıklanınca açılır.
class DevModeDialog extends ConsumerStatefulWidget {
  const DevModeDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext _) => const DevModeDialog(),
    );
  }

  @override
  ConsumerState<DevModeDialog> createState() => _DevModeDialogState();
}

class _DevModeDialogState extends ConsumerState<DevModeDialog> {
  late DevModeState _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _state = ref.read(devModeServiceProvider).current;
  }

  Future<void> _setEnabled(bool v) async {
    setState(() => _busy = true);
    final DevModeState next =
        await ref.read(devModeServiceProvider).setEnabled(v);
    ref.invalidate(devModeStateProvider);
    if (!mounted) return;
    setState(() {
      _state = next;
      _busy = false;
    });
  }

  Future<void> _setDisableAds(bool v) async {
    final DevModeState next =
        await ref.read(devModeServiceProvider).setDisableAds(v);
    ref.invalidate(devModeStateProvider);
    if (!mounted) return;
    setState(() => _state = next);
  }

  Future<void> _setFastDialog(bool v) async {
    final DevModeState next =
        await ref.read(devModeServiceProvider).setFastSolvedDialog(v);
    ref.invalidate(devModeStateProvider);
    if (!mounted) return;
    setState(() => _state = next);
  }

  Future<void> _bonus() async {
    setState(() => _busy = true);
    await ref.read(progressServiceProvider).devAddPoints(50);
    await ref.read(coinServiceProvider).addCoins(500);
    ref.invalidate(playerProgressProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('+50 Bulmaca Puanı  •  +500 jeton')),
    );
  }

  Future<void> _resetProgress() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Progress sıfırlansın mı?'),
        content: const Text(
          'Tüm çözümler, yıldızlar, başarımlar ve jetonlar silinir. Bu '
          'işlem geri alınamaz.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    await ref.read(progressServiceProvider).reset();
    ref.invalidate(playerProgressProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress sıfırlandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Text('🛠️ ', style: TextStyle(fontSize: 22)),
          Expanded(
            child: Text(
              'Dev Modu',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dev modu açık'),
              subtitle: const Text(
                'Kapatınca tüm bayraklar sıfırlanır',
              ),
              value: _state.enabled,
              onChanged: _busy ? null : _setEnabled,
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reklamları kapat'),
              subtitle: const Text(
                'Interstitial atlanır, rewarded otomatik başarılı',
              ),
              value: _state.disableAds,
              onChanged:
                  (_busy || !_state.enabled) ? null : _setDisableAds,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hızlı solved animasyonu'),
              subtitle: const Text(
                'Doğru cevap dialogu 100ms (1500 yerine)',
              ),
              value: _state.fastSolvedDialog,
              onChanged:
                  (_busy || !_state.enabled) ? null : _setFastDialog,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text('+50 Bulmaca Puanı  •  +500 Jeton'),
              onPressed: (_busy || !_state.enabled) ? null : _bonus,
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, color: Colors.red),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
              label: const Text(
                'Progress Sıfırla',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: (_busy || !_state.enabled) ? null : _resetProgress,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
