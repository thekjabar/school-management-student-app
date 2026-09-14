import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

const int kNoticeMinIqd = 250;
const int kNoticeMaxIqd = 500000000;

String payeeText(PaymentPayee payee, String key) =>
    t('${payee == PaymentPayee.ksp ? 'appFee' : 'schoolFees'}.$key');

String methodName(String method) => switch (method.toUpperCase()) {
      'CASH' => t('payments.mCash'),
      'BANK_TRANSFER' => t('payments.mBankTransfer'),
      'FIB' => t('payments.mFib'),
      'FASTPAY' => t('payments.mFastpay'),
      'ZAINCASH' => t('payments.mZaincash'),
      'ASIAHAWALA' => t('payments.mAsiahawala'),
      _ => t('payments.mOther'),
    };

IconData methodIcon(String method) => switch (method.toUpperCase()) {
      'CASH' => Icons.payments_rounded,
      'BANK_TRANSFER' => Icons.account_balance_rounded,
      'FIB' || 'FASTPAY' || 'ZAINCASH' || 'ASIAHAWALA' => Icons.smartphone_rounded,
      _ => Icons.more_horiz_rounded,
    };

int? parseAmountIqd(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.writeCharCode(rune);
    } else if (rune >= 0x660 && rune <= 0x669) {
      buffer.writeCharCode(0x30 + rune - 0x660);
    } else if (rune >= 0x6F0 && rune <= 0x6F9) {
      buffer.writeCharCode(0x30 + rune - 0x6F0);
    }
  }
  final digits = buffer.toString().replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (digits.isEmpty) return null;
  if (digits.length > 12) return kNoticeMaxIqd + 1;
  return int.tryParse(digits);
}

String? amountProblem(PaymentPayee payee, int? amount) {
  if (amount == null) return null;
  if (amount < kNoticeMinIqd) return t('payments.amountFloor');
  if (amount > kNoticeMaxIqd) return payeeText(payee, 'ceiling');
  return null;
}

(Color, String) noticeStatusOf(PaymentNotice notice) => switch (notice.status) {
      NoticeStatus.pending => (AppTheme.amber, payeeText(notice.payee, 'pending')),
      NoticeStatus.confirmed => (AppTheme.green, t('payments.statusConfirmed')),
      NoticeStatus.rejected => (AppTheme.rose, t('payments.statusRejected')),
      _ => (AppTheme.textMuted, t('payments.statusWithdrawn')),
    };

class NoticeTarget {
  const NoticeTarget({
    required this.studentId,
    required this.schoolId,
    required this.childName,
    required this.schoolName,
  });

  factory NoticeTarget.of(FamilyChildFees child) => NoticeTarget(
        studentId: child.studentId,
        schoolId: child.schoolId,
        childName: child.childName,
        schoolName: child.school,
      );

  final String studentId;
  final String schoolId;
  final String childName;
  final String schoolName;
}

sealed class NoticeOutcome {
  const NoticeOutcome();
}

class NoticeDelivered extends NoticeOutcome {
  const NoticeDelivered(this.sent);

  final NoticeSent sent;
}

class NoticeRefused extends NoticeOutcome {
  const NoticeRefused(this.message);

  final String message;
}

Future<void> tellPayment(
  BuildContext context, {
  required PaymentPayee payee,
  required NoticeTarget target,
  required List<String> methods,
  required VoidCallback onChanged,
  int? suggestedIqd,
}) async {
  final outcome = await showAppSheet<NoticeOutcome>(
    context,
    builder: (_) => PaymentNoticeSheet(
      payee: payee,
      target: target,
      methods: methods,
      suggestedIqd: suggestedIqd,
    ),
  );
  if (outcome == null || !context.mounted) return;
  onChanged();
  switch (outcome) {
    case NoticeDelivered(:final sent):
      showNote(context, sent.text(payeeText(payee, 'pending')));
    case NoticeRefused(:final message):
      showNote(context, message, bad: true);
  }
}

class PaymentNoticeSheet extends StatefulWidget {
  const PaymentNoticeSheet({
    super.key,
    required this.payee,
    required this.target,
    required this.methods,
    this.suggestedIqd,
  });

  final PaymentPayee payee;
  final NoticeTarget target;
  final List<String> methods;
  final int? suggestedIqd;

  @override
  State<PaymentNoticeSheet> createState() => _PaymentNoticeSheetState();
}

class _PaymentNoticeSheetState extends State<PaymentNoticeSheet> {
  static const _maxReference = 120;
  static const _maxSender = 160;
  static const _maxPhone = 20;
  static const _maxNote = 1000;

  late final String _idempotencyKey;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _senderName = TextEditingController();
  final _senderPhone = TextEditingController();
  final _note = TextEditingController();

  String? _method;
  DateTime _paidOn = DateUtils.dateOnly(DateTime.now());
  String? _proofAssetId;
  bool _uploadingProof = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _nonce();
    final suggested = widget.suggestedIqd;
    if (suggested != null && suggested >= kNoticeMinIqd && suggested <= kNoticeMaxIqd) {
      _amount.text = '$suggested';
    }
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _senderName.dispose();
    _senderPhone.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _nonce() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final salt = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'ksp-$now-$salt';
  }

  int? get _amountIqd => parseAmountIqd(_amount.text);

  bool get _ready =>
      _amountIqd != null &&
      amountProblem(widget.payee, _amountIqd) == null &&
      _method != null &&
      !_uploadingProof;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await pickDate(
      context,
      initial: _paidOn,
      first: DateTime(now.year - 1, now.month, now.day),
      last: now,
      tint: Role.parent.tint,
      title: t('payments.when'),
    );
    if (picked == null) return;
    setState(() => _paidOn = DateUtils.dateOnly(picked));
  }

  Future<void> _attachProof() async {
    final source = await pickOne<ImageSource>(
      context,
      tint: Role.parent.tint,
      title: t('payments.slipAdd'),
      options: [
        PickOption(
          value: ImageSource.camera,
          label: t('payments.slipPhotograph'),
          icon: Icons.photo_camera_rounded,
        ),
        PickOption(
          value: ImageSource.gallery,
          label: t('payments.slipFromPhone'),
          icon: Icons.photo_library_rounded,
        ),
      ],
    );
    if (source == null) return;

    setState(() {
      _uploadingProof = true;
      _error = null;
    });
    try {
      final shot = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 80);
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      final id = await ParentApi.instance.uploadFile(
        bytes: bytes,
        filename: 'slip.jpg',
        mime: 'image/jpeg',
        kind: 'PAYMENT_PROOF',
        studentId: widget.target.studentId,
        tenantId: widget.target.schoolId,
        capturedAt: DateTime.now(),
      );
      if (mounted) setState(() => _proofAssetId = id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = t('payments.slipFailed'));
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  Future<void> _send() async {
    if (!_ready || _busy) return;
    final amount = _amountIqd!;
    final method = _method!;

    final yes = await confirmDialog(
      context,
      icon: Icons.send_rounded,
      tone: Role.parent.tint,
      title: payeeText(widget.payee, 'confirmTitle'),
      body: tv('payments.confirmBody', {
        'amount': iqd(amount),
        'method': methodName(method),
        'date': longDate(_paidOn),
        'name': widget.target.childName,
      }),
      confirmLabel: t('payments.send'),
      confirmIcon: Icons.send_rounded,
    );
    if (!yes || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await ParentApi.instance.submitPaymentNotice(
        widget.payee,
        studentId: widget.target.studentId,
        schoolId: widget.target.schoolId,
        amountIqd: amount,
        method: method,
        idempotencyKey: _idempotencyKey,
        paidOn: _paidOn,
        reference: _reference.text,
        senderName: _senderName.text,
        senderPhone: _senderPhone.text,
        proofAssetId: _proofAssetId,
        notes: _note.text,
      );
      if (mounted) Navigator.of(context).pop<NoticeOutcome>(NoticeDelivered(sent));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.errorCode == SchoolFeesCode.notInApp) {
        Navigator.of(context).pop<NoticeOutcome>(NoticeRefused(e.message));
        return;
      }
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final problem = amountProblem(widget.payee, _amountIqd);
    final body = widget.payee == PaymentPayee.ksp
        ? tv('appFee.sheetBody', {'name': widget.target.childName})
        : tv('schoolFees.sheetBody', {'school': widget.target.schoolName});

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(18, 10, 18, 18)),
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
                payeeText(widget.payee, 'sheetTitle'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                body,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),
              NoticeDetail(icon: Icons.person_rounded, text: widget.target.childName),
              if (widget.payee == PaymentPayee.school)
                NoticeDetail(icon: Icons.school_rounded, text: widget.target.schoolName),
              const SizedBox(height: 14),
              _Label(t('payments.amount')),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('payments.amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: t('payments.amountHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              if (problem != null) ...[
                const SizedBox(height: 6),
                Text(problem, style: TextStyle(fontSize: 11.5, color: AppTheme.rose)),
              ],
              const SizedBox(height: 18),
              _Label(t('payments.method')),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in widget.methods)
                    _MethodChip(
                      key: ValueKey('payments.method.$method'),
                      label: methodName(method),
                      icon: methodIcon(method),
                      on: method == _method,
                      onTap: () => setState(() => _method = method),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _Label(t('payments.when')),
              const SizedBox(height: 8),
              _DateField(value: _paidOn, onTap: _pickDate),
              const SizedBox(height: 14),
              _ProofAttachment(
                attached: _proofAssetId != null,
                busy: _uploadingProof,
                onPick: _attachProof,
                onClear: () => setState(() => _proofAssetId = null),
              ),
              const SizedBox(height: 18),
              _Label(t('payments.reference')),
              const SizedBox(height: 8),
              TextField(
                controller: _reference,
                maxLength: _maxReference,
                decoration: InputDecoration(
                  hintText: t('payments.referenceHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              _Label(t('payments.senderName')),
              const SizedBox(height: 8),
              TextField(
                controller: _senderName,
                maxLength: _maxSender,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: t('payments.senderNameHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              _Label(t('payments.senderPhone')),
              const SizedBox(height: 8),
              TextField(
                controller: _senderPhone,
                maxLength: _maxPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(contentPadding: EdgeInsets.all(14)),
              ),
              _Label(t('payments.note')),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: _maxNote,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(contentPadding: EdgeInsets.all(14)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(fontSize: 12, color: AppTheme.rose)),
              ],
              const SizedBox(height: 12),
              BigButton(
                key: const ValueKey('payments.send'),
                label: t('payments.send'),
                color: tint,
                busy: _busy,
                onPressed: _ready ? _send : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentsDesk<T> extends StatefulWidget {
  const PaymentsDesk({
    super.key,
    required this.title,
    required this.payee,
    required this.loadOverview,
    required this.isEmpty,
    required this.builder,
  });

  final String title;
  final PaymentPayee payee;
  final Future<T> Function() loadOverview;
  final bool Function(T overview) isEmpty;
  final Widget Function(BuildContext context, T overview, List<PaymentNotice> notices, VoidCallback reload) builder;

  @override
  State<PaymentsDesk<T>> createState() => _PaymentsDeskState<T>();
}

class _DeskData<T> {
  const _DeskData(this.overview, this.notices);

  final T overview;
  final NoticePage notices;
}

class _PaymentsDeskState<T> extends State<PaymentsDesk<T>> {
  final _loaderKey = GlobalKey<LoaderState<_DeskData<T>>>();
  final List<PaymentNotice> _older = [];
  String? _cursor;
  bool _hasMore = false;
  bool _loadingOlder = false;
  int _generation = 0;

  Future<_DeskData<T>> _load() async {
    final generation = ++_generation;
    final results = await Future.wait<Object?>([
      widget.loadOverview(),
      ParentApi.instance.paymentNotices(widget.payee),
    ]);
    final page = results[1] as NoticePage;
    if (generation == _generation) {
      _older.clear();
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
      _loadingOlder = false;
    }
    return _DeskData<T>(results[0] as T, page);
  }

  void _reload() => _loaderKey.currentState?.reload();

  Future<void> _showOlder() async {
    final cursor = _cursor;
    if (cursor == null || _loadingOlder) return;
    final generation = _generation;
    setState(() => _loadingOlder = true);
    try {
      final page = await ParentApi.instance.paymentNotices(widget.payee, after: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _older.addAll(page.rows);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) showNote(context, errorText(e), bad: true);
    } finally {
      if (mounted && generation == _generation) setState(() => _loadingOlder = false);
    }
  }

  List<PaymentNotice> _merged(NoticePage first) {
    final seen = <String>{};
    return [
      for (final n in [...first.rows, ..._older])
        if (seen.add(n.id)) n,
    ];
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
            ScreenHeader(title: widget.title),
            Expanded(
              child: Loader<_DeskData<T>>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: _load,
                empty: t('payments.noChildren'),
                isEmpty: (data) => widget.isEmpty(data.overview),
                builder: (context, data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.builder(context, data.overview, _merged(data.notices), _reload),
                    if (_hasMore) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton.icon(
                          key: const ValueKey('payments.showOlder'),
                          onPressed: _loadingOlder ? null : _showOlder,
                          icon: _loadingOlder
                              ? SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: tint),
                                )
                              : const Icon(Icons.history_rounded, size: 18),
                          label: Text(t('payments.showOlder')),
                          style: TextButton.styleFrom(foregroundColor: tint),
                        ),
                      ),
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

class ChildPaymentsHeading extends StatelessWidget {
  const ChildPaymentsHeading({super.key, required this.name, required this.sub});

  final String name;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Chip36(icon: Icons.person_rounded, color: Role.parent.tint),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.text,
                ),
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class NoticeHistory extends StatelessWidget {
  const NoticeHistory({
    super.key,
    required this.payee,
    required this.childName,
    required this.notices,
    required this.onChanged,
  });

  final PaymentPayee payee;
  final String childName;
  final List<PaymentNotice> notices;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Heading(payeeText(payee, 'history')),
        if (notices.isEmpty)
          Card16(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Text(
              tv('${payee == PaymentPayee.ksp ? 'appFee' : 'schoolFees'}.historyEmpty', {'name': childName}),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
            ),
          )
        else
          for (var i = 0; i < notices.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == notices.length - 1 ? 0 : kCardGap),
              child: NoticeCard(
                key: ValueKey('notice.${notices[i].id}'),
                notice: notices[i],
                onChanged: onChanged,
              ),
            ),
      ],
    );
  }
}

class NoticeCard extends StatefulWidget {
  const NoticeCard({super.key, required this.notice, required this.onChanged});

  final PaymentNotice notice;
  final VoidCallback onChanged;

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final n = widget.notice;
    final yes = await confirmDialog(
      context,
      icon: Icons.undo_rounded,
      tone: AppTheme.rose,
      title: t('payments.withdrawTitle'),
      body: payeeText(n.payee, 'withdrawBody'),
      confirmLabel: t('payments.withdraw'),
      confirmIcon: Icons.undo_rounded,
    );
    if (!yes || !mounted) return;

    setState(() => _busy = true);
    try {
      await ParentApi.instance.withdrawPaymentNotice(n.payee, n);
      if (!mounted) return;
      widget.onChanged();
      showNote(context, t('payments.withdrawn'));
    } on ApiException catch (e) {
      if (!mounted) return;
      showNote(context, errorText(e), bad: true);
      if (e.status == 409) widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final (colour, word) = noticeStatusOf(n);
    final coverage = _coverage(n);

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip36(icon: methodIcon(n.method), color: colour),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      iqd(n.amountIqd),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${methodName(n.method)}  •  ${tn('payments.paidOn', longDate(n.paidOn ?? n.createdAt))}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(word, color: colour),
            ],
          ),
          const SizedBox(height: 10),
          if (n.reference != null) NoticeDetail(icon: Icons.tag_rounded, text: tn('payments.refLine', n.reference!)),
          if (n.hasProof) NoticeDetail(icon: Icons.receipt_rounded, text: t('payments.slipSent')),
          if (!n.sentByMe) NoticeDetail(icon: Icons.people_alt_rounded, text: t('payments.byOther')),
          if (n.confirmed && n.decidedAt != null)
            NoticeDetail(icon: Icons.verified_rounded, text: tn('payments.confirmedOn', longDate(n.decidedAt))),
          if (coverage != null) NoticeDetail(icon: Icons.event_available_rounded, text: coverage),
          if (n.withdrawn && n.withdrawnAt != null)
            NoticeDetail(icon: Icons.undo_rounded, text: tn('payments.withdrawnOn', longDate(n.withdrawnAt))),
          if (n.rejected && n.rejectedReason != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payeeText(n.payee, 'reason'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colour),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.rejectedReason!,
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.text),
                  ),
                ],
              ),
            ),
          ],
          if (n.pending) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _MiniButton(
                key: ValueKey('payments.withdraw.${n.id}'),
                label: t('payments.withdraw'),
                icon: Icons.undo_rounded,
                colour: AppTheme.rose,
                busy: _busy,
                onTap: _withdraw,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _coverage(PaymentNotice n) {
    if (!n.confirmed || n.payee != PaymentPayee.ksp || n.coverFrom == null) return null;
    final from = longDate(n.coverFrom);
    if (n.coverUntil == null) return tv('appFee.coversOpen', {'from': from});
    return tv('appFee.covers', {'from': from, 'until': longDate(n.coverUntil)});
  }
}

class NoticeDetail extends StatelessWidget {
  const NoticeDetail({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppTheme.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    super.key,
    required this.label,
    required this.icon,
    required this.colour,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: colour),
              )
            else
              Icon(icon, size: 15, color: colour),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colour),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofAttachment extends StatelessWidget {
  const _ProofAttachment({
    required this.attached,
    required this.busy,
    required this.onPick,
    required this.onClear,
  });

  final bool attached;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return InkWell(
      onTap: busy ? null : (attached ? onClear : onPick),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: attached ? tint.withValues(alpha: 0.08) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: attached ? tint.withValues(alpha: 0.45) : AppTheme.border),
        ),
        child: Row(
          children: [
            if (busy)
              SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: tint),
              )
            else
              Icon(
                attached ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                size: 19,
                color: attached ? tint : AppTheme.textMuted,
              ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                busy
                    ? t('payments.slipUploading')
                    : attached
                        ? t('payments.slipAttached')
                        : t('payments.slipAdd'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: attached ? FontWeight.w600 : FontWeight.w500,
                  color: attached ? tint : AppTheme.text,
                ),
              ),
            ),
            if (attached && !busy)
              Text(
                t('payments.slipRemove'),
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    super.key,
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: AppTheme.dark ? 0.18 : 0.08) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: on ? tint : AppTheme.textMuted),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? tint : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppTheme.text,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 15, color: AppTheme.textMuted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                longDate(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.text,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}
