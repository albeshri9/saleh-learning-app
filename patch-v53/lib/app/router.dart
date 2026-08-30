import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/character/video/saleh_video_dev_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/world_screen.dart';
import '../features/lesson/lesson_screen.dart';
import '../features/lesson/foundation_track.dart';

/// مسارات التطبيق. المسارات معلنة ومعرّفة بالمعرفات (وليس بالمحتوى)،
/// فأي درس جديد من لوحة المحتوى يعمل بنفس المسار /lesson/:id.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const WorldScreen(),
      ),
    ),
    GoRoute(
      path: '/program/:programId',
      pageBuilder: (context, state) => _smoothPage(
        state,
        ProgramScreen(programId: state.pathParameters['programId']!),
      ),
    ),
    GoRoute(
      path: '/program/:programId/stage/:stageId',
      pageBuilder: (context, state) => _smoothPage(
        state,
        StageScreen(
          programId: state.pathParameters['programId']!,
          stageId: state.pathParameters['stageId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/program/:programId/stage/:stageId/level/:levelId',
      pageBuilder: (context, state) => _smoothPage(
        state,
        LevelScreen(
          programId: state.pathParameters['programId']!,
          stageId: state.pathParameters['stageId']!,
          levelId: state.pathParameters['levelId']!,
        ),
      ),
    ),
    GoRoute(
      path: '/saleh/video',
      pageBuilder: (context, state) => _smoothPage(
        state,
        const SalehVideoDevScreen(),
      ),
    ),
    GoRoute(
      path: '/lesson/:id',
      pageBuilder: (context, state) => _smoothPage(
        state,
        LessonScreen(
          lessonId: state.pathParameters['id']!,
          foundationTrack:
              FoundationTrack.parse(state.uri.queryParameters['mode']),
          // معاينة مشهد محدد مباشرة: /lesson/tha?scene=3
          initialScene: int.tryParse(state.uri.queryParameters['scene'] ?? ''),
        ),
      ),
    ),
  ],
);

CustomTransitionPage<void> _smoothPage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 430),
      reverseTransitionDuration: const Duration(milliseconds: 380),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-.085, 0),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
