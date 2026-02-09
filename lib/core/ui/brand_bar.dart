import 'package:flutter/material.dart';

class BrandBar extends StatelessWidget {
  const BrandBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.logoAsset,
  });

  final String title;
  final String subtitle;
  final String logoAsset;

  static const Color brandBlue = Color(0xFF0E1524);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    // “mobile width” threshold
    final isNarrow = w < 560;

    return Container(
      color: brandBlue,
      padding: EdgeInsets.fromLTRB(16, isNarrow ? 14 : 18, 16, isNarrow ? 14 : 18),
      child: Row(
        mainAxisAlignment:
            isNarrow ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Image.asset(
            logoAsset,
            height: isNarrow ? 42 : 50, // ✅ bigger
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.72),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}