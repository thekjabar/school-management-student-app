import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/push.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../login_screen.dart' show LanguagePicker, ThemeToggle;

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key, required this.onSignedIn, this.offline = false});

  final void Function(Me me) onSignedIn;
  final bool offline;

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();

  String? _tenantId;

  bool _busy = false;
  bool _obscure = true;
  bool _choosing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.offline) _error = t('common.offline');
    if (Session.passwordChangeRequired) {
      Session.passwordChangeRequired = false;
      _error = t('login.mustChangeAgain');
    }
    _code.addListener(() => setState(() => _tenantId = null));
  }

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _next.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _error = t('student.codeNeeded'));
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = t('login.passwordNeeded'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await Session.instance.signInAsStudent(_code.text, _password.text);
      _tenantId = result.me.active.tenantId;
      if (!mounted) return;
      if (result.mustChangePassword) {
        setState(() => _choosing = true);
        return;
      }
      unawaited(Push.askPermission());
      widget.onSignedIn(result.me);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.status == 401) _password.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
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
      await Session.instance.changePassword(_password.text, _next.text);
      final again =
          await Session.instance.signInAsStudent(_code.text, _next.text, tenantId: _tenantId);
      if (!mounted) return;
      unawaited(Push.askPermission());
      widget.onSignedIn(again.me);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const role = Role.student;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: ColoredBox(
        color: role.wash,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final art = (box.maxHeight * 0.18).clamp(78.0, 132.0);

              return SingleChildScrollView(
                padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(16, 10, 16, 56)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        LanguagePicker(tint: role.tint),
                        const Spacer(),
                        ThemeToggle(tint: role.tint),
                      ],
                    ),
                    SizedBox(height: art * 0.16),
                    _Crest(size: art, tint: role.tint),
                    SizedBox(height: art * 0.16),
                    _Card(child: _choosing ? _chooseForm(role) : _signInForm(role)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _signInForm(Role role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tv('login.welcomeRole', {'role': t('role.student')}),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t('student.loginSubtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 18),

        _Field(
          icon: Icons.badge_outlined,
          tint: role.tint,
          label: t('student.code'),
          trailing: _code.text.trim().isNotEmpty
              ? Icon(Icons.check_circle_rounded, size: 22, color: AppTheme.green)
              : null,
          child: TextField(
            controller: _code,
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            autocorrect: false,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppTheme.text,
            ),
            decoration: const InputDecoration(
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            t('student.codeHint'),
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 16),

        _Field(
          icon: Icons.lock_outline_rounded,
          tint: role.tint,
          label: t('login.password'),
          trailing: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            behavior: HitTestBehavior.opaque,
            child: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 21,
              color: AppTheme.textFaint,
            ),
          ),
          child: TextField(
            controller: _password,
            focusNode: _passwordFocus,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _signIn(),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: _obscure ? 2 : -0.3,
              color: AppTheme.text,
            ),
            decoration: const InputDecoration(
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),

        if (_error != null) _ErrorLine(_error!),

        const SizedBox(height: 16),
        BigButton(
          label: t('welcome.logIn'),
          color: role.tint,
          busy: _busy,
          height: 52,
          onPressed: _signIn,
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Icon(Icons.family_restroom_rounded, size: 22, color: role.tint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t('student.forgotBody'),
                style: TextStyle(fontSize: 11.5, height: 1.5, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chooseForm(Role role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Chip36(icon: Icons.key_rounded, color: role.tint, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('login.choose'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3,
                  color: AppTheme.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          t('student.chooseWhy'),
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 20),
        _Field(
          icon: Icons.lock_outline_rounded,
          tint: role.tint,
          label: t('login.newPassword'),
          child: TextField(
            controller: _next,
            obscureText: true,
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppTheme.text,
            ),
            decoration: const InputDecoration(
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Text(
            t('login.rule'),
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 14),
        _Field(
          icon: Icons.lock_outline_rounded,
          tint: role.tint,
          label: t('login.typeAgain'),
          child: TextField(
            controller: _confirm,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _choose(),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppTheme.text,
            ),
            decoration: const InputDecoration(
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (_error != null) _ErrorLine(_error!),
        const SizedBox(height: 20),
        BigButton(
          label: t('login.saveContinue'),
          color: role.tint,
          busy: _busy,
          height: 56,
          onPressed: _choose,
        ),
      ],
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest({required this.size, required this.tint});

  final double size;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          boxShadow: AppTheme.dark
              ? null
              : const [BoxShadow(color: Color(0x14101828), blurRadius: 22, offset: Offset(0, 8))],
        ),
        child: Icon(Icons.auto_stories_rounded, size: size * 0.46, color: tint),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: AppTheme.dark ? Border.all(color: AppTheme.border) : null,
        boxShadow: AppTheme.dark
            ? null
            : const [BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.tint,
    required this.child,
    this.label,
    this.trailing,
  });

  final IconData icon;
  final Color tint;
  final Widget child;
  final String? label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) ...[
                  Text(label!, style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                ],
                child,
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.rose),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.rose),
            ),
          ),
        ],
      ),
    );
  }
}
