// frontend/lib/main.dart

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

// Use ConsumerWidget to access Riverpod providers like routerProvider
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Access the GoRouter instance via routerProvider
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'YavaSuite',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router, // Connect GoRouter here
    );
  }
}
