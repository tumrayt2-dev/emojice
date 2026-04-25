import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/service_providers.dart';

/// Açılış ekranı — uygulama servislerini hazırlarken büyük emoji + başlık
/// ve yükleniyor animasyonu gösterir.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    // Servislerin başlangıç işlemleri.
    final Stopwatch sw = Stopwatch()..start();
    try {
      await ref.read(progressServiceProvider).init();
      await ref.read(purchaseServiceProvider).init();
      await ref.read(adServiceProvider).init();
    } catch (_) {
      // İlk açılışta servis başlatma hataları ana akışı bloklamasın.
    }
    // En az 900 ms splash kalsın ki kullanıcı görebilsin.
    final int elapsed = sw.elapsedMilliseconds;
    if (elapsed < 900) {
      await Future<void>.delayed(Duration(milliseconds: 900 - elapsed));
    }
    if (!mounted) {
      return;
    }
    context.go('/');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF1A1130),
              Color(0xFF2A1A4A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.06).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: const Text(
                    '🎯',
                    style: TextStyle(fontSize: 120),
                  ),
                ),
                const SizedBox(height: 24),
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: <Color>[
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ).createShader(bounds);
                  },
                  child: Text(
                    'EMOJİ TAHMİN',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Yükleniyor...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
