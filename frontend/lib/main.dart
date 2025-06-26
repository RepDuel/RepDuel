import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Convert MyApp to a ConsumerWidget to access the router provider.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the router provider to get the GoRouter instance.
    final router = ref.watch(routerProvider);

    // Use MaterialApp.router to integrate GoRouter.
    return MaterialApp.router(
      title: 'YavaSuite',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}