// frontend/lib/widgets/loading_spinner.dart

import 'package:flutter/material.dart';

class LoadingSpinner extends StatelessWidget {
  final String? message;
  final double? size; // <<< 1. ADD THE SIZE PROPERTY

  const LoadingSpinner({
    super.key, 
    this.message,
    this.size, // <<< 2. ADD TO CONSTRUCTOR
  });

  @override
  Widget build(BuildContext context) {
    // 3. USE THE SIZE PROPERTY
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        // Optionally, make strokeWidth smaller for smaller spinners
        strokeWidth: size != null && size! < 30 ? 3.0 : 4.0,
      ),
    );

    if (message == null && size != null) {
      // If only size is provided, just return the indicator.
      return indicator;
    }
    
    // Default behavior: centered column
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator,
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}