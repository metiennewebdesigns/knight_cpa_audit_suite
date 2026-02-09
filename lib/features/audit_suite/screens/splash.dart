import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String route = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  Timer? _timer;

  // Auditron blue (you referenced this earlier as the target)
  static const Color _bg = Color(0xFF0E1524);

  // ✅ Make sure this filename matches exactly what’s in assets/branding/
  static const String _logoAsset = 'assets/branding/auditron_logo_dark.png';

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.96, end: 1.02).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );

    _c.forward();

    // Total splash time ≈ 2s
    _timer = Timer(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      // small fade out
      await _c.reverse(from: 1.0);
      if (!mounted) return;

      // go to dashboard root
      context.go('/');
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            return Opacity(
              opacity: _fade.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Image.asset(
                  _logoAsset,
                  // “luxury” sizing: responsive but not tiny
                  width: MediaQuery.of(context).size.width < 520 ? 220 : 360,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}