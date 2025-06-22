import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/screens/home_screen.dart';

void main() {
  runApp(
    const ProviderScope( // <-- wrap entire app here
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YavaSuite',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}
