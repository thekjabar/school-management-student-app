import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';
import '../../ui/signature_pad.dart';

String consentPurposeLabel(String purpose) =>
    tOr('consent.purpose.$purpose', humanise(purpose));

String consentStopLine(String purpose) =>
    tOr('consent.stop.$purpose', t('consent.stopGeneric'));

({String label, Color colour}) consentStatusLook(String? status) => switch (status) {
      'GRANTED' => (label: t('consent.status.GRANTED'), colour: AppTheme.green),
      'REFUSED' => (label: t('consent.status.REFUSED'), colour: AppTheme.textMuted),
      'WITHDRAWN' => (label: t('consent.status.WITHDRAWN'), colour: AppTheme.rose),
      'EXPIRED' => (label: t('consent.status.EXPIRED'), colour: AppTheme.amber),
      'SUPERSEDED' => (label: t('consent.status.SUPERSEDED'), colour: AppTheme.textMuted),
      null => (label: t('consent.status.NONE'), colour: AppTheme.blue),
      _ => (
          label: tOr('consent.status.$status', humanise(status)),
          colour: AppTheme.textMuted,
        ),
    };

String? consentAnsweredLine(ConsentForm form) {
  if (form.withdrawnAt != null) return tn('consent.withdrawnOn', longDate(form.withdrawnAt));
  if (form.signedAt != null) return tn('consent.signedOn', longDate(form.signedAt));
  if (form.grantedAt != null) return tn('consent.answeredOn', longDate(form.grantedAt));
  return null;
}

class ConsentFormScreen extends StatefulWidget {
  const ConsentFormScreen({
    super.key,
    required this.studentId,
    required this.childName,
    required this.policyVersionId,
  });

  final String studentId;
  final String childName;
  final String policyVersionId;

  @override
  State<ConsentFormScreen> createState() => _ConsentFormScreenState();
}

class _ConsentFormScreenState extends State<ConsentFormScreen> {
  final _loaderKey = GlobalKey<LoaderState<ConsentFormDetail>>();

  bool _busy = false;

  Future<void> _agree(ConsentFormDetail detail) async {
    final form = detail.form;
    if (form.wording == null) return;

    final title = consentPurposeLabel(form.purpose);

    final signature = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => _SignatureScreen(formTitle: title, childName: detail.name),
      ),
    );
    if (signature == null || !mounted) return;

    final sure = await confirmDialog(
      context,
      icon: Icons.verified_user_rounded,
      tone: Role.parent.tint,
      title: t('consent.agreeConfirmTitle'),
      body: tv('consent.agreeConfirmBody', {'form': title, 'name': detail.name}),
      confirmLabel: t('consent.agree'),
      confirmIcon: Icons.check_rounded,
    );
    if (!sure || !mounted) return;

    await _send(() async {
      final signatureMediaId = await ParentApi.instance.uploadFile(
        bytes: signature,
        filename: 'signature.png',
        mime: 'image/png',
        kind: 'SIGNATURE_IMAGE',
        studentId: detail.studentId,
      );
      return ParentApi.instance.signConsent(
        studentId: detail.studentId,
        purpose: form.purpose,
        policyVersionId: form.policyVersionId,
        answer: 'GRANTED',
        signatureMediaId: signatureMediaId,
      );
    });
  }

  Future<void> _refuse(ConsentFormDetail detail) async {
    final form = detail.form;
    if (form.wording == null) return;

    final title = consentPurposeLabel(form.purpose);

    final sure = await confirmDialog(
      context,
      icon: Icons.gpp_maybe_rounded,
      tone: AppTheme.amber,
      title: t('consent.refuseConfirmTitle'),
      body: tv('consent.refuseConfirmBody', {'form': title, 'name': detail.name}),
      confirmLabel: t('consent.refuse'),
      confirmIcon: Icons.block_rounded,
    );
    if (!sure || !mounted) return;

    await _send(
      () => ParentApi.instance.signConsent(
        studentId: detail.studentId,
        purpose: form.purpose,
        policyVersionId: form.policyVersionId,
        answer: 'REFUSED',
      ),
    );
  }

  Future<void> _send(Future<ConsentForm> Function() answer) async {
    setState(() => _busy = true);
    try {
      final saved = await answer();
      if (!mounted) return;
      showNote(context, saved.granted ? t('consent.savedAgreed') : t('consent.savedRefused'));
      _loaderKey.currentState?.reload();
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(ConsentFormDetail detail) async {
    final consentId = detail.form.consentId;
    if (consentId == null) return;

    final reason = await showAppSheet<String>(
      context,
      builder: (_) => _WithdrawSheet(purpose: detail.form.purpose, childName: detail.name),
    );
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ParentApi.instance.withdrawConsent(consentId: consentId, reason: reason);
      if (!mounted) return;
      showNote(context, t('consent.withdrawDone'));
      _loaderKey.currentState?.reload();
    } catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
            ScreenHeader(title: t('consent.title'), subtitle: widget.childName),
            Expanded(
              child: Loader<ConsentFormDetail>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 32),
                load: () => ParentApi.instance.consentForm(
                  policyVersionId: widget.policyVersionId,
                  studentId: widget.studentId,
                ),
                builder: (context, detail) => _Form(
                  detail: detail,
                  busy: _busy,
                  onAgree: () => _agree(detail),
                  onRefuse: () => _refuse(detail),
                  onWithdraw: () => _withdraw(detail),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.detail,
    required this.busy,
    required this.onAgree,
    required this.onRefuse,
    required this.onWithdraw,
  });

  final ConsentFormDetail detail;
  final bool busy;
  final VoidCallback onAgree;
  final VoidCallback onRefuse;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final form = detail.form;
    final wording = form.wording;
    final look = consentStatusLook(form.status);
    final answered = consentAnsweredLine(form);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card16(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      consentPurposeLabel(form.purpose),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.3,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusChip(look.label, color: look.colour),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                answered == null
                    ? tn('consent.version', form.version)
                    : '${tn('consent.version', form.version)}  •  $answered',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              if (form.recordedElsewhere) ...[
                const SizedBox(height: 8),
                Text(
                  t('consent.byOffice'),
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
                ),
              ],
              if (form.withdrawalReason != null && form.withdrawalReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  t('consent.yourReason'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  form.withdrawalReason!.trim(),
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.text),
                ),
              ],
            ],
          ),
        ),

        if (form.answered && form.onOlderWording) ...[
          const SizedBox(height: kCardGap),
          NoticeBanner(
            icon: Icons.history_rounded,
            color: AppTheme.amber,
            title: t('consent.olderWording'),
            body: t('consent.readFully'),
          ),
        ],

        const SizedBox(height: kCardGap),

        if (wording == null)
          NoticeBanner(
            icon: Icons.report_gmailerrorred_rounded,
            color: AppTheme.rose,
            title: t('consent.wordingMissing'),
            body: t('consent.readFully'),
          )
        else
          Card16(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wording.language != consentBodyLanguage()) ...[
                  Text(
                    tv('consent.wordingInOther', {
                      'lang': tOr('consent.lang.${wording.language}', wording.language),
                    }),
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.amber),
                  ),
                  const SizedBox(height: 12),
                ],
                Directionality(
                  textDirection:
                      wording.rightToLeft ? TextDirection.rtl : TextDirection.ltr,
                  child: Text(
                    wording.text,
                    textAlign: TextAlign.start,
                    style: TextStyle(fontSize: 13.5, height: 1.65, color: AppTheme.text),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: kCardGap),

        Card16(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Fact(
                icon: Icons.folder_outlined,
                text: form.retentionDays == null
                    ? t('consent.retentionUnset')
                    : tn('consent.retention', form.retentionDays!),
              ),
              if (form.expiresAt != null) ...[
                const SizedBox(height: 11),
                _Fact(
                  icon: Icons.event_busy_outlined,
                  text: tn('consent.expiresOn', longDate(form.expiresAt)),
                ),
              ],
              if (form.sharedWith.isNotEmpty) ...[
                const SizedBox(height: 11),
                _Fact(
                  icon: Icons.groups_outlined,
                  text: '${t('consent.sharedWith')}: ${form.sharedWith.join('  •  ')}',
                ),
              ],
              if (form.scopeNote != null && form.scopeNote!.trim().isNotEmpty) ...[
                const SizedBox(height: 11),
                _Fact(
                  icon: Icons.sticky_note_2_outlined,
                  text: '${t('consent.scopeNote')}: ${form.scopeNote!.trim()}',
                ),
              ],
              const SizedBox(height: 11),
              _Fact(icon: Icons.menu_book_outlined, text: t('consent.readFully')),
            ],
          ),
        ),

        if (wording != null) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: busy ? null : onAgree,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Icon(Icons.draw_rounded, size: 19),
              label: Text(
                t('consent.signAndAgree'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.border,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          if (detail.signatureRequiredToAgree) ...[
            const SizedBox(height: 8),
            Text(
              t('consent.signatureRequired'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: busy ? null : onRefuse,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.text,
                side: BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                t('consent.refuse'),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],

        if (form.canWithdraw) ...[
          const SizedBox(height: 18),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),
          Text(
            consentStopLine(form.purpose),
            style: TextStyle(fontSize: 11.5, height: 1.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onWithdraw,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: Text(
                t('consent.withdraw'),
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.rose,
                side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textFaint),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SignatureScreen extends StatefulWidget {
  const _SignatureScreen({required this.formTitle, required this.childName});

  final String formTitle;
  final String childName;

  @override
  State<_SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<_SignatureScreen> {
  final SignatureInk _ink = SignatureInk();

  bool _empty = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ink.addListener(_inkChanged);
  }

  @override
  void dispose() {
    _ink.removeListener(_inkChanged);
    _ink.dispose();
    super.dispose();
  }

  void _inkChanged() {
    final empty = _ink.isEmpty;
    if (empty != _empty) setState(() => _empty = empty);
  }

  Future<void> _use() async {
    setState(() => _saving = true);

    Uint8List? bytes;
    try {
      bytes = await _ink.toPng();
    } catch (e) {
      debugPrint('signature: could not render the drawing to a png: $e');
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (bytes == null || bytes.isEmpty) {
      showNote(context, t('consent.signatureFailed'), bad: true);
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: t('consent.signTitle'), subtitle: widget.childName),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 2, kGutter, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.formTitle,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    t('consent.signLead'),
                    style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        if (_empty)
                          Center(
                            child: Text(
                              t('consent.signHere'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppTheme.textFaint),
                            ),
                          ),
                        Positioned.fill(
                          child: SignaturePad(ink: _ink, colour: AppTheme.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _empty || _saving ? null : _ink.clear,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.text,
                          side: BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          t('common.clear'),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _empty || _saving ? null : _use,
                        style: FilledButton.styleFrom(
                          backgroundColor: Role.parent.tint,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppTheme.border,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                t('consent.useSignature'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({required this.purpose, required this.childName});

  final String purpose;
  final String childName;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _reason = TextEditingController();

  String? _error;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _send() {
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = t('consent.withdrawReasonShort'));
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('consent.withdrawTitle'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${consentPurposeLabel(widget.purpose)}  •  ${widget.childName}',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.rose.withValues(alpha: 0.32)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.priority_high_rounded, size: 17, color: AppTheme.rose),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        consentStopLine(widget.purpose),
                        style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.rose),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t('consent.withdrawReason'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                autofocus: true,
                maxLength: 300,
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: t('consent.withdrawReasonHint'),
                  counterText: '',
                  filled: true,
                  fillColor: AppTheme.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.rose),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _reason.text.trim().length < 3 ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(
                    t('consent.withdrawSend'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
