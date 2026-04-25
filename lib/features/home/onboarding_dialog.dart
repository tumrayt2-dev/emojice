import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/service_providers.dart';

/// İlk açılışta gösterilen 3 sayfalık tanıtım. Kullanıcı "Atla" veya
/// "Başla" derse `OnboardingService.markSeen()` çağrılır.
class OnboardingDialog extends ConsumerStatefulWidget {
  const OnboardingDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext _) => const OnboardingDialog(),
    );
  }

  @override
  ConsumerState<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends ConsumerState<OnboardingDialog> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Page> _pages = <_Page>[
    _Page(
      emoji: '🤔',
      title: 'Emojilerden Cevabı Bul',
      body:
          'Yan yana dizilen emojilerden bir film, dizi, şarkı, atasözü ya '
          'da yer adını bulmaya çalış. Alttaki harfleri kullan, üst kutucukları '
          'doldur.',
    ),
    _Page(
      emoji: '🏆',
      title: 'Bulmaca Puanı Kazan',
      body:
          'Her doğru cevap +1 Bulmaca Puanı kazandırır. Reklam izleyerek de '
          '+5 puan kazanabilirsin. Toplam puan tier seviyeni belirler — daha '
          'fazla kategori açılır!',
    ),
    _Page(
      emoji: '🔓',
      title: 'Yeni Kategoriler Açılır',
      body:
          'Başlangıçta Hayvanlar, Yiyecekler ve Atasözleri açık. 20 puanda '
          'Türk Dizileri/Filmleri, 60 puanda Şarkılar/Spor… Her tier yeni '
          'kategoriler getirir. Kilit ekranındaki ipuçlarını oku!',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingServiceProvider).markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLast = _page == _pages.length - 1;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Kapat',
                    onPressed: _finish,
                  ),
                ),
              ),
              SizedBox(
                height: 360,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (int p) => setState(() => _page = p),
                  itemBuilder: (BuildContext context, int i) {
                    final _Page page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(page.emoji,
                              style: const TextStyle(fontSize: 84)),
                          const SizedBox(height: 16),
                          Text(
                            page.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            page.body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _page == i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? AppTheme.primaryColor
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  children: <Widget>[
                    if (!isLast)
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Atla'),
                      )
                    else
                      const SizedBox(width: 64),
                    const Spacer(),
                    FilledButton.icon(
                      icon: Icon(isLast
                          ? Icons.play_arrow_rounded
                          : Icons.arrow_forward_rounded),
                      label: Text(isLast ? 'Başla' : 'İleri'),
                      onPressed: () {
                        if (isLast) {
                          _finish();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Page {
  const _Page({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;
}
