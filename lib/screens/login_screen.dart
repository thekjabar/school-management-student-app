import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client.dart';
import '../api/push.dart';
import '../api/session.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import '../ui/async.dart';
import '../ui/kit.dart';

/// One screen: the language, the picture, and the form.
///
/// Not a welcome page with a sheet behind it. A parent opening this app has one
/// thing to do, and putting a "Get started" button in front of it costs a tap
/// and teaches nothing. The language pills come first, above everything that
/// needs reading — somebody who cannot read the form cannot find the setting
/// that would let them read it.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role, required this.onSignedIn});

  final Role role;
  final void Function(Me me) onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _busy = false;
  bool _obscure = true;
  bool _choosing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _next.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// A local number, as the school holds it. Eleven digits starting 07 is what
  /// every network here issues, and the tick appears the moment it is one.
  bool get _phoneLooksRight {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.startsWith('0');
  }

  Future<void> _signIn() async {
    if (!_phoneLooksRight) {
      setState(() => _error = t('login.phoneNeeded'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await Session.instance.signIn(_phone.text, _password.text);
      if (!mounted) return;
      if (result.mustChangePassword) {
        setState(() => _choosing = true);
        return;
      }
      unawaited(Push.askPermission());
      widget.onSignedIn(result.me);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      // Only wipe the field when the server actually rejected it. Clearing it
      // after a dropped connection makes somebody retype a password that was
      // right, which is how they end up believing it is wrong.
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
      // Changing a password ends every session it opened, this one included, so
      // the only honest next step is to sign in again with the new one.
      final again = await Session.instance.signIn(_phone.text, _next.text);
      if (!mounted) return;
      unawaited(Push.askPermission());
      widget.onSignedIn(again.me);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: ColoredBox(
        color: AppTheme.dark ? AppTheme.canvas : role.wash,
        child: Stack(
          children: [
            // The hills along the foot of the page, under everything.
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Image.asset(
                'assets/art/login_wave.png',
                fit: BoxFit.fitWidth,
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: LanguagePicker(tint: role.tint),
                    ),
                    const SizedBox(height: 30),
                    Image.asset('assets/art/login_family.png', height: 252),
                    const SizedBox(height: 6),
                    _Card(
                      child: _choosing ? _chooseForm(role) : _signInForm(role),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* --- The form ---------------------------------------------------------- */

  Widget _signInForm(Role role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t('login.welcomeBack'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          t('login.signInToContinue'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 22),

        _Field(
          icon: Icons.smartphone_rounded,
          tint: role.tint,
          label: t('login.phone'),
          trailing: _phoneLooksRight
              ? Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppTheme.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                )
              : null,
          child: TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            // Digits only. Every other character a phone keypad offers is one
            // the server will reject, and finding that out after typing is
            // worse than not being able to type it.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppTheme.text,
            ),
            decoration: InputDecoration(
              hintText: t('login.phoneHint'),
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
            t('login.phoneFormat'),
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Text(
            t('login.password'),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
            ),
          ),
        ),
        _Field(
          icon: Icons.lock_outline_rounded,
          tint: role.tint,
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

        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: GestureDetector(
            onTap: () => showNote(context, t('login.forgot')),
            behavior: HitTestBehavior.opaque,
            child: Text(
              t('login.forgotShort'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: role.tint,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        BigButton(
          label: t('welcome.logIn'),
          color: role.tint,
          busy: _busy,
          height: 56,
          onPressed: _signIn,
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_rounded, size: 22, color: role.tint),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('login.secure'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
                Text(
                  t('login.secureBody'),
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
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
          t('login.chooseWhy'),
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

/* ---------------------------------------------------------------------------
 * The pieces
 * ------------------------------------------------------------------------- */

/// The white panel the form sits on.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: AppTheme.dark ? Border.all(color: AppTheme.border) : null,
        boxShadow: AppTheme.dark
            ? null
            : const [
                BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 8)),
              ],
      ),
      child: child,
    );
  }
}

/// A field with its own icon chip, and the label INSIDE the box.
///
/// The design puts the label above the value inside the same bordered box
/// rather than above the box, which is what lets the phone number be typed at
/// the size it is read back at.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
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

/// Kurdish, Arabic, English — one pill each, the chosen one filled.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.tint});

  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? AppTheme.violet;

    return ValueListenableBuilder<Lang>(
      valueListenable: AppLocale.current,
      builder: (context, current, _) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppTheme.dark
              ? null
              : const [
                  BoxShadow(color: Color(0x0F101828), blurRadius: 10, offset: Offset(0, 3)),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in Lang.values)
              GestureDetector(
                onTap: current == lang ? null : () => AppLocale.set(lang),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: current == lang ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    lang.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: current == lang ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
