import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/player_progress.dart';
import '../../providers/service_providers.dart';
import '../../services/purchase_service.dart';

/// Mağaza ekranı — coin paketleri ve reklam kaldırma seçeneklerini sunar.
/// Plan gereği şu an MOCK satın alma ile çalışır (PurchaseService Hive'a yazar).
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<PlayerProgress> progressAsync =
        ref.watch(playerProgressProvider);
    final AsyncValue<Set<String>> purchasedAsync =
        ref.watch(purchasedProductsProvider);

    final int coins = progressAsync.maybeWhen<int>(
      data: (PlayerProgress p) => p.coins,
      orElse: () => 0,
    );
    final Set<String> purchased = purchasedAsync.maybeWhen<Set<String>>(
      data: (Set<String> s) => s,
      orElse: () => <String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CoinBadge(coins: coins),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        children: <Widget>[
          _SectionTitle(text: 'Coin Paketleri', theme: theme),
          const SizedBox(height: 8),
          _StoreCard(
            icon: '💰',
            title: '500 Coin',
            subtitle: 'İpucu kullanmak için harika başlangıç',
            buttonLabel: 'Satın Al',
            badgeText: '₺14,99',
            onTap: () => _buyCoinPack(
              context,
              ref,
              productId: PurchaseService.productCoin500,
            ),
          ),
          const SizedBox(height: 12),
          _StoreCard(
            icon: '💎',
            title: '1500 Coin',
            subtitle: 'Bonuslu paket — en avantajlı seçim',
            buttonLabel: 'Satın Al',
            badgeText: '₺34,99',
            highlight: true,
            onTap: () => _buyCoinPack(
              context,
              ref,
              productId: PurchaseService.productCoin1500,
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(text: 'Diğer', theme: theme),
          const SizedBox(height: 8),
          _StoreCard(
            icon: '⭐',
            title: 'Premium Paket',
            subtitle:
                'Reklamları kaldır + 500 jeton hediye + tier-açma reklamı bekleme süresi devreye girer',
            buttonLabel: purchased.contains(PurchaseService.productNoAds)
                ? 'Sahipsin'
                : 'Satın Al',
            disabled: purchased.contains(PurchaseService.productNoAds),
            badgeText: '₺24,99',
            onTap: () => _buyNoAdsBundle(context, ref),
          ),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Satın alımları geri yükle',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _restorePurchases(context, ref),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Satın Alımları Geri Yükle'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Future<void> _buyNoAdsBundle(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool ok = await ref
        .read(purchaseServiceProvider)
        .buyProduct(PurchaseService.productNoAds);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Satın alma başarısız.')),
      );
      return;
    }
    await ref
        .read(coinServiceProvider)
        .addCoins(PurchaseService.noAdsBonusCoins);
    ref.invalidate(purchasedProductsProvider);
    ref.invalidate(playerProgressProvider);
    messenger.showSnackBar(
      const SnackBar(
        content:
            Text('Premium paket aktif! Reklamlar kapandı + 500 jeton eklendi.'),
      ),
    );
  }

  Future<void> _buyCoinPack(
    BuildContext context,
    WidgetRef ref, {
    required String productId,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int amount = PurchaseService.coinAmounts[productId] ?? 0;
    final bool ok =
        await ref.read(purchaseServiceProvider).buyProduct(productId);
    if (ok && amount > 0) {
      await ref.read(coinServiceProvider).addCoins(amount);
      ref.invalidate(playerProgressProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('+$amount coin hesabına eklendi!')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Satın alma başarısız.')),
      );
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Set<String> set =
        await ref.read(purchaseServiceProvider).restorePurchases();
    ref.invalidate(purchasedProductsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          set.isEmpty
              ? 'Geri yüklenecek satın alma bulunamadı.'
              : '${set.length} satın alma geri yüklendi.',
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('💰', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.badgeText,
    required this.onTap,
    this.highlight = false,
    this.disabled = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String badgeText;
  final VoidCallback onTap;
  final bool highlight;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppTheme.secondaryColor.withValues(alpha: 0.6)
              : theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
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
                        color: AppTheme.secondaryColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: Semantics(
                    button: true,
                    enabled: !disabled,
                    label: '$title, $badgeText, $buttonLabel',
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: disabled
                            ? Colors.grey
                            : AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: disabled ? null : onTap,
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
