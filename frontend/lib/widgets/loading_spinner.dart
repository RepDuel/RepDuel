// frontend/lib/widgets/loading_spinner.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoadingSpinner extends StatefulWidget {
  final String? message;
  final double size;
  final double acceleration;
  final Duration duration;

  const LoadingSpinner({
    super.key,
    this.message,
    this.size = 60.0,
    this.acceleration = 1, // tweak 0.8–2.0 for feel
    this.duration = const Duration(milliseconds: 1500), // was 2s
  });

  @override
  State<LoadingSpinner> createState() => _LoadingSpinnerState();
}

class _LoadingSpinnerState extends State<LoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size * 0.15;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                // Fast ramp-up: progress = t + a*t²
                final progress = (t + widget.acceleration * t * t) % 1.0;
                final angle = 2 * math.pi * progress;

                return Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (i) {
                    final theta = angle + (i * 2 * math.pi / 3);
                    final dx = (widget.size / 2 - dotSize) * math.cos(theta);
                    final dy = (widget.size / 2 - dotSize) * math.sin(theta);

                    return Transform.translate(
                      offset: Offset(dx, dy),
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
