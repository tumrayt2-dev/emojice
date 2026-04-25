import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/categories/category_selection_screen.dart';
import '../features/game/game_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/how_to_play_screen.dart';
import '../features/levels/level_selection_screen.dart';
import '../features/purchase/store_screen.dart';
import '../features/splash/splash_screen.dart';

/// Uygulama genelindeki rotalar.
class AppRouter {
  AppRouter._();

  /// Splash dışındaki tüm ekranlar için ortak fade + hafif slide geçişi.
  static CustomTransitionPage<T> _fadeSlidePage<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      child: child,
      transitionsBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final Animation<Offset> offset = Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(curved);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: offset,
            child: child,
          ),
        );
      },
    );
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            // Splash kendi animasyonunu yönettiği için burada düz fade yerine
            // sade bir NoTransitionPage tercih ediyoruz.
            const NoTransitionPage<void>(child: SplashScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeSlidePage<void>(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/categories',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeSlidePage<void>(
          key: state.pageKey,
          child: const CategorySelectionScreen(),
        ),
      ),
      GoRoute(
        path: '/levels/:categoryId',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String categoryId = state.pathParameters['categoryId'] ?? '';
          return _fadeSlidePage<void>(
            key: state.pageKey,
            child: LevelSelectionScreen(categoryId: categoryId),
          );
        },
      ),
      GoRoute(
        path: '/game/:categoryId/:puzzleId',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String categoryId = state.pathParameters['categoryId'] ?? '';
          final String puzzleId = state.pathParameters['puzzleId'] ?? '';
          return _fadeSlidePage<void>(
            key: ValueKey<String>('game-$categoryId-$puzzleId'),
            child: GameScreen(
              key: ValueKey<String>('game-screen-$categoryId-$puzzleId'),
              categoryId: categoryId,
              puzzleId: puzzleId,
            ),
          );
        },
      ),
      // Karışık mod: tüm kategorilerden rastgele sorular gelir. Sabit
      // `'__mix__'` categoryId değeri GameScreen ve GameController için
      // karışık mod sinyalidir.
      GoRoute(
        path: '/random/:puzzleId',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final String puzzleId = state.pathParameters['puzzleId'] ?? '';
          return _fadeSlidePage<void>(
            key: ValueKey<String>('random-$puzzleId'),
            child: GameScreen(
              key: ValueKey<String>('game-screen-mix-$puzzleId'),
              categoryId: '__mix__',
              puzzleId: puzzleId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/how-to-play',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeSlidePage<void>(
          key: state.pageKey,
          child: const HowToPlayScreen(),
        ),
      ),
      GoRoute(
        path: '/store',
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _fadeSlidePage<void>(
          key: state.pageKey,
          child: const StoreScreen(),
        ),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Hata')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aradığın sayfa bulunamadı.\n${state.error?.message ?? ''}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
