import 'package:flutter/material.dart';

class PaywallLock extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const PaywallLock({
    super.key,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24)),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, color: Colors.amber, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
