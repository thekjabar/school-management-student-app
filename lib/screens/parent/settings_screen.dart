import 'package:flutter/material.dart';
import '../../ui/screen_kit.dart';

import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/settings_widgets.dart';
import '../../ui/sheets.dart';
import '../login_screen.dart' show LanguagePicker;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final me = Session.instance.me;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('settings.title')),
            Expanded(
              child: ListView(
                padding: withBottomInset(context, const EdgeInsets.fromLTRB(14, 4, 14, 24)),
        children: [
          _Section(t('settings.signedInAs')),
          Card16(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleInitials(label: me?.name ?? '', tint: tint, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me?.name ?? '',
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
                        me?.phone ?? '',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _Section(t('settings.appearance')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: ThemePicker(tint: tint),
          ),

          _Section(t('settings.language')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LanguagePicker(tint: tint),
            ),
          ),

          _Section(t('settings.notifications')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                PushRow(tint: tint),
                const _WhatsAppRow(),
              ],
            ),
          ),

          _Section(t('more.account')),
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TileRow(
              icon: Icons.lock_rounded,
              color: AppTheme.textMuted,
              title: t('more.changePassword'),
              subtitle: t('more.changePasswordSub'),
              last: true,
              onTap: () => showAppSheet<void>(
                context,
                builder: (_) => ChangePasswordSheet(tint: tint),
              ),
            ),
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppRow extends StatefulWidget {
  const _WhatsAppRow();

  @override
  State<_WhatsAppRow> createState() => _WhatsAppRowState();
}

class _WhatsAppRowState extends State<_WhatsAppRow> {
  WhatsAppChoice? _choice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final choice = await ParentApi.instance.whatsappChoice();
      if (mounted) setState(() => _choice = choice);
    } catch (_) {
      if (mounted) setState(() => _choice = null);
    }
  }

  Future<void> _set(bool enabled) async {
    final before = _choice;
    if (before == null) return;
    setState(() {
      _saving = true;
      _choice = WhatsAppChoice(offered: before.offered, enabled: enabled);
    });
    try {
      final saved = await ParentApi.instance.chooseWhatsapp(enabled: enabled);
      if (mounted) setState(() => _choice = saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _choice = before);
      showNote(context, t('more.whatsappFailed'), bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choice;
    if (choice == null || !choice.offered) return const SizedBox.shrink();
    final tint = Role.parent.tint;

    return Column(
      children: [
        Divider(height: 1, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Chip36(icon: Icons.chat_rounded, color: AppTheme.green),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('more.whatsapp'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choice.enabled ? t('more.whatsappOn') : t('more.whatsappOff'),
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: t('more.whatsapp'),
                toggled: choice.enabled,
                child: Switch(
                  value: choice.enabled,
                  onChanged: _saving ? null : _set,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  thumbColor: const WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? tint : AppTheme.textFaint,
                  ),
                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppTheme.textFaint,
        ),
      ),
    );
  }
}
