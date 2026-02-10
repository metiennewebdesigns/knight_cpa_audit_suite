import 'package:flutter/material.dart';

import 'core/storage/local_store.dart';
import 'app_router.dart';

// ✅ Demo gate + demo seeding
import 'features/audit_suite/services/demo_access.dart';
import 'features/audit_suite/services/demo_seeder.dart';
import 'features/audit_suite/screens/demo_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.init();
  final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

  runApp(AuditronApp(store: store, themeMode: themeMode));
}

class AuditronApp extends StatefulWidget {
  const AuditronApp({
    super.key,
    required this.store,
    required this.themeMode,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;

  @override
  State<AuditronApp> createState() => _AuditronAppState();
}

class _AuditronAppState extends State<AuditronApp> {
  // Keep router instance stable
  late final router = buildRouter(store: widget.store, themeMode: widget.themeMode);

  bool _checked = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _checkGate();
  }

  Future<void> _checkGate() async {
    // Gate disabled if no DEMO_CODE supplied
    if (!DemoAccess.isGateEnabled()) {
      // Optional: still seed demo data for your own local testing if you want
      // await DemoSeeder.seedIfNeeded(widget.store);

      if (!mounted) return;
      setState(() {
        _unlocked = true;
        _checked = true;
      });
      return;
    }

    final ok = await DemoAccess.isUnlocked(widget.store);

    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _checked = true;
    });
  }

  Future<void> _handleUnlocked() async {
    // ✅ Seed demo data once after successful unlock
    await DemoSeeder.seedIfNeeded(widget.store);

    if (!mounted) return;
    setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    // Simple boot screen while we read prefs
    if (!_checked) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Gate at app start
    if (!_unlocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: DemoGateScreen(
          store: widget.store,
          onUnlocked: _handleUnlocked,
        ),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeMode,
      builder: (context, mode, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
          routerConfig: router,
        );
      },
    );
  }
}