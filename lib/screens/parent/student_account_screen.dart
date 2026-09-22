import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

class StudentAccountScreen extends StatefulWidget {
  const StudentAccountScreen({super.key});

  @override
  State<StudentAccountScreen> createState() => _StudentAccountScreenState();
}

class _StudentAccountScreenState extends State<StudentAccountScreen> {
  final _loader = GlobalKey<LoaderState<StudentAppAccounts>>();
  final _busy = <String>{};

  Future<void> _switch(StudentAppAccount child, bool enabled) async {
    setState(() => _busy.add(child.studentId));
    try {
      await ParentApi.instance.switchStudentAccount(child.studentId, enabled: enabled);
      if (!mounted) return;
      showNote(
        context,
        enabled
            ? tv('studentAccount.turnedOn', {'name': _firstName(child)})
            : tv('studentAccount.turnedOff', {'name': _firstName(child)}),
      );
      _loader.currentState?.reload(quiet: true);
    } catch (e) {
      if (!mounted) return;
      showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy.remove(child.studentId));
    }
  }

  Future<void> _setPassword(StudentAppAccount child) async {
    final password = await showAppSheet<String>(
      context,
      builder: (_) => _PasswordSheet(childName: _firstName(child)),
    );
    if (password == null || !mounted) return;

    setState(() => _busy.add(child.studentId));
    try {
      await ParentApi.instance.setStudentPassword(child.studentId, password);
      if (!mounted) return;
      showNote(context, tv('studentAccount.passwordSaved', {'name': _firstName(child)}));
      _loader.currentState?.reload(quiet: true);
    } catch (e) {
      if (!mounted) return;
      showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy.remove(child.studentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: t('studentAccount.title'),
              subtitle: t('studentAccount.subtitle'),
            ),
            Expanded(
              child: Loader<StudentAppAccounts>(
                key: _loader,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                load: () => ParentApi.instance.studentAccounts(),
                empty: t('common.noChildren'),
                isEmpty: (accounts) => accounts.children.isEmpty,
                builder: (context, accounts) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!accounts.schoolOpen)
                      NoticeBanner(
                        icon: Icons.lock_clock_rounded,
                        color: AppTheme.amber,
                        title: t('studentAccount.schoolClosed'),
                        body: t('studentAccount.schoolClosedBody'),
                      )
                    else
                      NoticeBanner(
                        icon: Icons.phone_iphone_rounded,
                        color: tint,
                        title: t('studentAccount.whatItIs'),
                        body: tn('studentAccount.fromGrade', accounts.minGradeLevel),
                      ),
                    const SizedBox(height: kCardGap),
                    for (final child in accounts.children) ...[
                      _ChildCard(
                        child: child,
                        busy: _busy.contains(child.studentId),
                        onSwitch: (on) => _switch(child, on),
                        onPassword: () => _setPassword(child),
                      ),
                      const SizedBox(height: kCardGap),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstName(StudentAppAccount child) => child.displayName.split(' ').first;

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.busy,
    required this.onSwitch,
    required this.onPassword,
  });

  final StudentAppAccount child;
  final bool busy;
  final ValueChanged<bool> onSwitch;
  final VoidCallback onPassword;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitials(label: child.displayName, tint: tint, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child.code,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (child.canOpenTheApp)
                StatusChip(t('studentAccount.ready'), color: AppTheme.green)
              else if (child.enabled)
                StatusChip(t('studentAccount.needsPassword'), color: AppTheme.amber)
              else
                StatusChip(t('studentAccount.off'), color: AppTheme.textFaint),
            ],
          ),
          const SizedBox(height: 12),
          if (child.blockedByOffice)
            _Why(icon: Icons.block_rounded, text: t('studentAccount.officeClosedIt'))
          else if (!child.oldEnough)
            _Why(icon: Icons.child_care_rounded, text: t('studentAccount.tooYoung'))
          else if (!child.mayBeSwitchedOn)
            _Why(icon: Icons.lock_clock_rounded, text: t('studentAccount.schoolClosed'))
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('studentAccount.letThemIn'),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        child.enabled
                            ? t('studentAccount.onBody')
                            : t('studentAccount.offBody'),
                        style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: t('studentAccount.letThemIn'),
                  toggled: child.enabled,
                  child: Switch(
                    value: child.enabled,
                    onChanged: busy ? null : onSwitch,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    thumbColor: const WidgetStatePropertyAll(Colors.white),
                    trackColor: WidgetStateProperty.resolveWith(
                      (states) =>
                          states.contains(WidgetState.selected) ? tint : AppTheme.textFaint,
                    ),
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: BigButton(
                label: child.passwordSet
                    ? t('studentAccount.resetPassword')
                    : t('studentAccount.setPassword'),
                color: tint,
                height: 46,
                onPressed: busy ? null : onPassword,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              child.passwordSet
                  ? t('studentAccount.passwordIsSet')
                  : t('studentAccount.noPasswordYet'),
              style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Why extends StatelessWidget {
  const _Why({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppTheme.textFaint),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.childName});

  final String childName;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _next.text;
    if (password.length < 8) {
      setState(() => _error = t('login.tooShort'));
      return;
    }
    if (!RegExp(r'(?=.*[A-Za-z])(?=.*\d)').hasMatch(password)) {
      setState(() => _error = t('login.rule'));
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = t('login.mismatch'));
      return;
    }
    Navigator.of(context).pop(password);
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
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(20, 12, 20, 24)),
        child: SingleChildScrollView(
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
                tv('studentAccount.passwordFor', {'name': widget.childName}),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('studentAccount.passwordWhy'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _next,
                obscureText: true,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: InputDecoration(labelText: t('login.newPassword')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirm,
                obscureText: true,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                decoration: InputDecoration(labelText: t('login.confirmPassword')),
              ),
              const SizedBox(height: 10),
              Text(
                t('login.rule'),
                style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textMuted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppTheme.rose, fontSize: 12.5)),
              ],
              const SizedBox(height: 18),
              BigButton(
                label: t('common.save'),
                color: Role.parent.tint,
                height: 50,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
