import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/storage/local_store.dart';
import '../services/demo_access.dart';

class DemoGateScreen extends StatefulWidget {
  const DemoGateScreen({
    super.key,
    required this.store,
    required this.onUnlocked,
  });

  final LocalStore store;
  final VoidCallback onUnlocked;

  @override
  State<DemoGateScreen> createState() => _DemoGateScreenState();
}

class _DemoGateScreenState extends State<DemoGateScreen> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final ok = DemoAccess.validate(_codeCtrl.text);
      if (!ok) {
        setState(() => _error = 'Incorrect demo code.');
        return;
      }

      await DemoAccess.unlock(widget.store);
      widget.onUnlocked();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await DemoAccess.reset(widget.store);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo access reset ✅')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final hint = kIsWeb
        ? 'Enter the demo access code you were provided (web demo).'
        : 'Enter the demo access code you were provided.';

    final gateEnabled = DemoAccess.isGateEnabled();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 42, color: cs.primary),
                    const SizedBox(height: 10),
                    const Text(
                      'Auditron Demo Access',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Demo code',
                        border: const OutlineInputBorder(),
                        errorText: _error,
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show' : 'Hide',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Text(_busy ? 'Checking…' : 'Unlock'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy ? null : _reset,
                      child: const Text('Reset demo access'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gateEnabled
                          ? 'Gate enabled (DEMO_CODE is set).'
                          : 'Gate disabled (no DEMO_CODE set).',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.65)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}