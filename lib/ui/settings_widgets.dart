import 'package:flutter/material.dart';

import '../api/push.dart';
import '../api/session.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'async.dart';
import 'kit.dart';

class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.tint});

  final Color tint;

  IconData _icon(AppThemeMode m) => switch (m) {
        AppThemeMode.system => Icons.brightness_auto_rounded,
        AppThemeMode.light => Icons.light_mode_rounded,
        AppThemeMode.dark => Icons.dark_mode_rounded,
      };

  String _label(AppThemeMode m) => switch (m) {
        AppThemeMode.system => t('theme.system'),
        AppThemeMode.light => t('theme.light'),
        AppThemeMode.dark => t('theme.dark'),
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: AppThemeSetting.current,
      builder: (context, current, _) => Row(
        children: [
          for (final mode in AppThemeMode.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: current == mode ? null : () => AppThemeSetting.set(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: current == mode
                        ? tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.12)
                        : AppTheme.canvas,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: current == mode ? tint : AppTheme.border,
                      width: current == mode ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _icon(mode),
                        size: 19,
                        color: current == mode ? tint : AppTheme.textMuted,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _label(mode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: current == mode ? FontWeight.w700 : FontWeight.w600,
                          color: current == mode ? AppTheme.text : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PushRow extends StatefulWidget {
  const PushRow({super.key, required this.tint});

  final Color tint;

  @override
  State<PushRow> createState() => _PushRowState();
}

class _PushRowState extends State<PushRow> with WidgetsBindingObserver {
  bool _granted = Push.granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _granted = Push.granted);
    }
  }

  Future<void> _ask() async {
    final ok = await Push.askPermission();
    if (!mounted) return;
    setState(() => _granted = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('more.pushBlocked'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TileRow(
      icon: _granted ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
      color: _granted ? AppTheme.green : AppTheme.amber,
      title: t('more.push'),
      subtitle: _granted ? t('more.pushOn') : t('more.pushOff'),
      trailing: _granted ? null : t('more.turnOn'),
      last: true,
      onTap: _granted ? null : _ask,
    );
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key, required this.tint});

  final Color tint;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.length < 8) {
      setState(() => _error = t('login.tooShort'));
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = t('login.mismatch'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Session.instance.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('more.passwordChanged'))),
      );
    } catch (e) {
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t('more.changePassword'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t('more.changePasswordSub'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            _Field(controller: _current, label: t('more.currentPassword')),
            const SizedBox(height: 10),
            _Field(controller: _next, label: t('login.newPassword')),
            const SizedBox(height: 10),
            _Field(controller: _confirm, label: t('login.confirmPassword')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: AppTheme.rose, fontSize: 12.5)),
            ],
            const SizedBox(height: 18),
            BigButton(
              label: _busy ? t('common.saving') : t('common.save'),
              color: widget.tint,
              height: 50,
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      decoration: InputDecoration(labelText: label),
    );
  }
}
