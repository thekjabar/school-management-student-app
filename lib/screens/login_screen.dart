import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client.dart';
import '../api/push.dart';
import '../api/session.dart';
import '../theme/app_theme.dart';
import '../i18n/strings.dart';
import '../ui/kit.dart';
import '../ui/school_scene.dart';

/// The way into the app.
///
/// A welcome, and then a sheet that rises over it. The form never gets a page
/// of its own: a phone number and a password are two fields, and giving them a
/// whole white screen with a logo stranded above is what makes a sign-in look
/// like the first thing somebody ever built.
///
/// The number is the identity. There are no usernames anywhere in this product,
/// because the school already holds a verified number for every guardian and
/// every member of staff, and a second identifier would only be one more thing
/// to lose.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role, required this.onSignedIn});

  final Role role;
  final void Function(Me me) onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _sheetOpen = false;

  Future<void> _openSheet() async {
    if (_sheetOpen) return;
    setState(() => _sheetOpen = true);

    final me = await showModalBottomSheet<Me>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // The welcome stays visible and dims behind the sheet, so the app never
      // blinks to a blank form.
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder: (_) => _SignInSheet(role: widget.role),
    );

    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (me != null) widget.onSignedIn(me);
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [role.wash, AppTheme.canvas],
            stops: const [0, 0.62],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 26),
                  child: Column(
                    children: [
                      // First thing on the screen, deliberately. A parent who
                      // cannot read the sign-in form cannot find the setting
                      // that would let them read it — so the choice comes
                      // before anything that needs reading.
                      const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: LanguagePicker(),
                      ),
                      const Spacer(flex: 2),
                      _Brand(role: role),
                      const Spacer(flex: 1),
                      // Capped so the artwork never crowds the buttons on a
                      // short phone — it is decoration, and decoration yields.
                      SchoolScene(
                        tint: role.tint,
                        height: (constraints.maxHeight * 0.30).clamp(150.0, 230.0),
                      ),
                      const Spacer(flex: 2),
                      BigButton(
                        label: t('welcome.getStarted'),
                        color: role.tint,
                        height: 52,
                        onPressed: _openSheet,
                      ),
                      const SizedBox(height: 11),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _openSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.text,
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                          child: Text(t('welcome.logIn')),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('welcome.usePhone'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textFaint, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.role});

  final Role role;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: role.tint,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: role.tint.withValues(alpha: 0.36),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 33),
        ),
        const SizedBox(height: 16),
        Text(
          t('app.name'),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.9),
        ),
        const SizedBox(height: 7),
        Text(
          t('app.tagline'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: AppTheme.textMuted, height: 1.5),
        ),
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * The sheet
 * ------------------------------------------------------------------------- */

class _SignInSheet extends StatefulWidget {
  const _SignInSheet({required this.role});

  final Role role;

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
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
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _next.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_phone.text.trim().length < 7) {
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
      Navigator.of(context).pop(result.me);
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
      Navigator.of(context).pop(again.me);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;

    return Padding(
      // The sheet rides above the keyboard rather than hiding behind it.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _choosing ? _chooseForm(role) : _signInForm(role),
            ],
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
          t('login.welcomeBack'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6),
        ),
        const SizedBox(height: 5),
        Text(
          t('login.subtitle'),
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.45),
        ),
        const SizedBox(height: 24),
        _Label(t('login.phone')),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofocus: true,
          // Digits only. Every other character a phone keypad offers is one the
          // server will reject, and finding that out after typing is worse.
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: InputDecoration(
            hintText: t('login.phoneHint'),
            prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: AppTheme.textFaint),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
          ),
        ),
        const SizedBox(height: 16),
        _Label(t('login.password')),
        TextField(
          controller: _password,
          focusNode: _passwordFocus,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _signIn(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.textFaint),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 19,
                color: AppTheme.textFaint,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (_error != null) _ErrorLine(_error!),
        const SizedBox(height: 22),
        BigButton(
          label: t('login.signIn'),
          color: role.tint,
          busy: _busy,
          height: 52,
          onPressed: _signIn,
        ),
        const SizedBox(height: 14),
        Text(
          t('login.forgot'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.textFaint, height: 1.5),
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
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          t('login.chooseWhy'),
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 22),
        _Label(t('login.newPassword')),
        TextField(
          controller: _next,
          obscureText: true,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.textFaint),
            prefixIconConstraints: BoxConstraints(minWidth: 44),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t('login.rule'),
          style: const TextStyle(color: AppTheme.textFaint, fontSize: 11.5),
        ),
        const SizedBox(height: 16),
        _Label(t('login.typeAgain')),
        TextField(
          controller: _confirm,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _choose(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.textFaint),
            prefixIconConstraints: BoxConstraints(minWidth: 44),
          ),
        ),
        if (_error != null) _ErrorLine(_error!),
        const SizedBox(height: 22),
        BigButton(
          label: t('login.saveContinue'),
          color: role.tint,
          busy: _busy,
          height: 52,
          onPressed: _choose,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted),
      ),
    );
  }
}

/// An error in the same shape as the app's other bad news: a tinted band, not
/// bare red text floating between two fields.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: AppTheme.roseSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.rose),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: AppTheme.rose, fontSize: 12.5, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// The three languages, as a segmented row.
///
/// A row rather than a dropdown: there are three, they are short, and a parent
/// who cannot read the current language should not have to open a menu written
/// in it to find their own. Every label is written in its own script, so it is
/// legible whatever the app is currently set to.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Lang>(
      valueListenable: AppLocale.current,
      builder: (context, current, _) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in Lang.values)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: current == lang ? null : () => AppLocale.set(lang),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: current == lang ? AppTheme.text : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    lang.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: current == lang ? FontWeight.w700 : FontWeight.w600,
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
