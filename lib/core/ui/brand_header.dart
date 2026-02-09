import 'package:flutter/material.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.logoAssetPath,
    this.tagline = 'Professional Audit Workflow & Verification Platform',
  });

  final String logoAssetPath;
  final String tagline;

  // ✅ Brand navy (use the exact color you want here)
  // This fixes the Light mode “tagline disappears” issue because we always
  // render the header on a dark brand background with light text.
  static const Color brandNavy = Color(0xFF0E1524);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isNarrow = w < 520;

    // Always keep contrast high
    const textColor = Color(0xFFE9EEF7);

    return Material(
      color: brandNavy,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 14 : 18,
            vertical: isNarrow ? 12 : 14,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                brandNavy,
                Color.lerp(brandNavy, Colors.black, 0.08)!,
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment:
                    isNarrow ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Image.asset(
                    logoAssetPath,
                    // ✅ bigger logo
                    height: isNarrow ? 44 : 54,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tagline,
                textAlign: isNarrow ? TextAlign.center : TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor.withOpacity(0.80),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}