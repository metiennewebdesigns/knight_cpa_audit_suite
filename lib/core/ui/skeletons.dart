import 'package:flutter/material.dart';

/// Simple “skeleton” shimmer without dependencies.
/// Uses animated opacity + theme colors so it looks good in dark/light.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = 12,
  });

  final double height;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.75),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [base, highlight, base],
              ),
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 18, width: 260),
                SizedBox(height: 10),
                SkeletonBox(height: 14, width: 160),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 28, radius: 999)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 28, radius: 999)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 28, radius: 999)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}