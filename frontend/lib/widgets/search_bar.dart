// frontend/lib/widgets/search_bar.dart

import 'package:flutter/material.dart';

class ExerciseSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final EdgeInsetsGeometry? margin;

  const ExerciseSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search exercises',
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white70,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }
}
