import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/sheets.dart';

Future<void> showIdCard(BuildContext context) => showAppSheet<void>(
      context,
      builder: (_) => const StudentIdCardSheet(),
    );

class StudentIdCardSheet extends StatefulWidget {
  const StudentIdCardSheet({super.key});

  @override
  State<StudentIdCardSheet> createState() => _StudentIdCardSheetState();
}

class _StudentIdCardSheetState extends State<StudentIdCardSheet> {
  StudentProfile? _profile;
  IdCardToken? _card;
  String? _error;
  bool _busy = true;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _beat());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _beat() {
    if (!mounted) return;
    final card = _card;
    if (card != null && card.remaining == Duration.zero && !_busy) {
      unawaited(_refreshToken());
      return;
    }
    setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await StudentApi.instance.me();
      final card = await StudentApi.instance.idCard();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _card = card;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _busy = false;
      });
    }
  }

  Future<void> _refreshToken() async {
    setState(() => _busy = true);
    try {
      final card = await StudentApi.instance.idCard();
      if (!mounted) return;
      setState(() {
        _card = card;
        _error = null;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: withBottomInset(context, const EdgeInsets.fromLTRB(20, 12, 20, 24)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip36(icon: Icons.verified_user_rounded, color: tint, size: 32),
                const SizedBox(width: 9),
                Text(
                  t('student.idCard'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t('student.idCardBody'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
            ),
            const SizedBox(height: 18),
            _body(tint),
          ],
        ),
      ),
    );
  }

  Widget _body(Color tint) {
    final card = _card;
    final profile = _profile;

    if (card == null || profile == null) {
      if (_error != null) {
        return Column(
          children: [
            Icon(Icons.wifi_off_rounded, size: 30, color: AppTheme.rose),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: t('common.tryAgain'),
              color: tint,
              height: 48,
              onPressed: _load,
            ),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 46),
        child: CircularProgressIndicator(strokeWidth: 2.6, color: tint),
      );
    }

    final left = card.remaining;
    final className = profile.schoolClass?.name ?? '';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: QrImageView(
            data: card.token,
            size: 216,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF111827),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          profile.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: tint,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            Pill(profile.code, color: tint),
            if (className.isNotEmpty) Pill(className, color: AppTheme.blue),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          profile.schoolName,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.textFaint),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _busy ? Icons.autorenew_rounded : Icons.timelapse_rounded,
              size: 15,
              color: AppTheme.textMuted,
            ),
            const SizedBox(width: 7),
            Text(
              _busy
                  ? t('student.idCardRenewing')
                  : tn('student.idCardExpires', left.inSeconds),
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BigButton(
          label: t('student.idCardRefresh'),
          color: tint,
          height: 48,
          busy: _busy,
          onPressed: _refreshToken,
        ),
      ],
    );
  }
}
