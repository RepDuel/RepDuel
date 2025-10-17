// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/config/env.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  usePathUrlStrategy();

  if (!kIsWeb) {
    await dotenv.load(fileName: ".env").catchError((error) {
      debugPrint(
        'Note: .env file not found or failed to load. Using compile-time environment variables instead.',
      );
    });
  }

  const backendUrlDefine = String.fromEnvironment('BACKEND_URL');
  const publicBaseUrlDefine = String.fromEnvironment('PUBLIC_BASE_URL');
  debugPrint("Env: --dart-define BACKEND_URL = '$backendUrlDefine'");
  debugPrint("Env: --dart-define PUBLIC_BASE_URL = '$publicBaseUrlDefine'");
  debugPrint('Env: resolved backendUrl = ${Env.backendUrl}');

  // Initialize Stripe
  if (!kIsWeb) {
    Stripe.publishableKey = Env.stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'RepDuel',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
