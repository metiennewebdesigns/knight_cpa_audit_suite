import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../storage/local_store.dart';
import '../../features/audit_suite/widgets/global_search_sheet.dart';

class AuditShell extends StatefulWidget {
  const AuditShell({
    super.key,
    required this.store,
    required this.themeMode,
    required this.navigationShell,
  });

  final LocalStore store;
  final ValueNotifier<ThemeMode> themeMode;
  final StatefulNavigationShell navigationShell;

  @override
  State<AuditShell> createState() => _AuditShellState();
}

class _AuditShellState extends State<AuditShell> {
  int get _index => widget.navigationShell.currentIndex;

  void _go(int index) {
    widget.navigationShell.goBranch(index, initialLocation: index == _index);
  }

  void _openSearch() {
    GlobalSearchSheet.open(context, store: widget.store);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Keyboard shortcuts:
    // - macOS: ⌘K
    // - Windows/Linux: Ctrl+K
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const _OpenSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): const _OpenSearchIntent(),
    };

    final actions = <Type, Action<Intent>>{
      _OpenSearchIntent: CallbackAction<_OpenSearchIntent>(
        onInvoke: (_) {
          _openSearch();
          return null;
        },
      ),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: const Color(0xFF0E1524),
              foregroundColor: Colors.white,
              elevation: 0,
              toolbarHeight: 92,
              titleSpacing: 16,
              title: const _AnimatedLogoTagline(
                logoPath: 'assets/branding/auditron_logo_dark.png',
                logoSize: 120,
                tagline: 'Evidence. Verified.', // <- change anytime
              ),
              actions: [
                IconButton(
                  tooltip: 'Search (⌘K / Ctrl+K)',
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
                IconButton(
                  tooltip: 'Theme',
                  icon: Icon(_themeIcon(widget.themeMode.value)),
                  onPressed: () {
                    final cur = widget.themeMode.value;
                    widget.themeMode.value =
                        (cur == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: widget.navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              backgroundColor: cs.surface,
              onDestinationSelected: _go,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment),
                  label: 'Clients',
                ),
                NavigationDestination(
                  icon: Icon(Icons.work_outline),
                  selectedIcon: Icon(Icons.work),
                  label: 'Engagements',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_open_outlined),
                  selectedIcon: Icon(Icons.folder_open),
                  label: 'Workpapers',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===================== Animated header widget ===================== */

class _AnimatedLogoTagline extends StatefulWidget {
  const _AnimatedLogoTagline({
    required this.logoPath,
    required this.logoSize,
    required this.tagline,
  });

  final String logoPath;
  final double logoSize;
  final String tagline;

  @override
  State<_AnimatedLogoTagline> createState() => _AnimatedLogoTaglineState();
}

class _AnimatedLogoTaglineState extends State<_AnimatedLogoTagline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(-0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    SchedulerBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Row(
          children: [
            Image.asset(
              widget.logoPath,
              height: widget.logoSize,
              width: widget.logoSize,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.verified_outlined,
                color: Colors.white,
                size: widget.logoSize * 0.5,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              widget.tagline,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12, // smaller tagline
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenSearchIntent extends Intent {
  const _OpenSearchIntent();
}

IconData _themeIcon(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return Icons.dark_mode;
    case ThemeMode.light:
      return Icons.light_mode;
    case ThemeMode.system:
      return Icons.brightness_auto;
  }
}