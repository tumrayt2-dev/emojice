import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Nasıl oynanır ekranı — sayfalı (PageView) anlatım.
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_HelpPage> _pages = <_HelpPage>[
    _HelpPage(
      emoji: '🎯',
      title: 'Emojileri gör, ne olduğunu tahmin et!',
      description:
          'Ekranda gösterilen emoji kombinasyonu bir filmi, atasözünü, şarkıyı veya deyimi temsil eder. Dikkatlice incele!',
    ),
    _HelpPage(
      emoji: '🔤',
      title: 'Alttaki harflerden doğru kelimeyi oluştur',
      description:
          'Karışık harflere tıklayarak cevabı yaz. Yanlış yaptığında harfleri temizleyip tekrar deneyebilirsin.',
    ),
    _HelpPage(
      emoji: '💡',
      title: 'İpucu kullan: harf aç veya yanlış harfleri ele',
      description:
          'Zorlandığında coinlerini harcayarak ipucu al. Sana doğru harfi açar ya da yanlış harfleri eleyebilir.',
    ),
    _HelpPage(
      emoji: '🪙',
      title: 'Coin kazan, yeni bölümler aç',
      description:
          'Her doğru cevap sana puan ve coin kazandırır. Bölümler ilerledikçe zorluk da artar!',
    ),
    _HelpPage(
      emoji: '👑',
      title: 'Premium kategorilerle daha fazla eğlence!',
      description:
          'Premium kategorilerin kilidini aç ve yüzlerce yeni bulmacayla eğlenmeye devam et.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLast = _index == _pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nasıl Oynanır?'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext context, int i) {
                  return _HelpPageView(page: _pages[i]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'Anladım' : 'İleri',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpPage {
  const _HelpPage({
    required this.emoji,
    required this.title,
    required this.description,
  });

  final String emoji;
  final String title;
  final String description;
}

class _HelpPageView extends StatelessWidget {
  const _HelpPageView({required this.page});

  final _HelpPage page;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 96),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
