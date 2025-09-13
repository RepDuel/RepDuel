// frontend/lib/widgets/loading_spinner.dart

import 'package:flutter/material.dart';

class LoadingSpinner extends StatelessWidget {
  final String? message;
  final double? size;

  const LoadingSpinner({
    super.key,
    this.message,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: size != null && size! < 30 ? 3.0 : 4.0,
      ),
    );

    if (message == null && size != null) {
      return indicator;
    }

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
