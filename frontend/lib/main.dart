// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Import flutter_dotenv
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

// 2. Make the main function async
Future<void> main() async {
  // 3. Ensure Flutter bindings are initialized before any async operations
  WidgetsFlutterBinding.ensureInitialized();
  
  // 4. Load environment variables from the .env file
  await dotenv.load(fileName: ".env");

  // Your original code remains the same from here
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
      title: 'RepDuel',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router, // Connect GoRouter here
    );
  }
}