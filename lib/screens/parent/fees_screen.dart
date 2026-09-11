import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});

  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  final _loaderKey = GlobalKey<LoaderState<_Desk>>();
  int _tab = 0;

  Future<_Desk> _load() async {
    final api = ParentApi.instance;

    final opening = await Future.wait<Object?>([api.fees(), api.paymentOptions()]);
    final summary = opening[0] as FeeSummary;
    final options = opening[1] as PaymentOptions?;

    if (options == null) return _Desk(summary: summary);

    final rest = await Future.wait<Object?>([
      api.payments(),
      api.receipts(),
      if (options.allowSelfDeclare) api.children(),
    ]);
    final payments = rest[0] as Paged<DeclaredPayment>;
    final receipts = rest[1] as Paged<PaymentReceipt>;

    return _Desk(
      summary: summary,
      options: options,
      payments: payments.rows,
      paymentsTotal: payments.total,
      receipts: receipts.rows,
      receiptsTotal: receipts.total,
      children: rest.length > 2 ? rest[2] as List<Child> : const [],
    );
  }

  void _reload() => _loaderKey.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('fees.title')),
            Expanded(
              child: Loader<_Desk>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: _load,
                builder: (context, desk) {
                  final tab = desk.moneyDesk ? _tab : 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (desk.moneyDesk) ...[
                        const SizedBox(height: 4),
                        PillTabs(
                          tint: tint,
                          index: tab,
                          onChanged: (i) => setState(() => _tab = i),
                          tabs: [
                            TabSpec(
                              label: t('fees.tabBills'),
                              icon: Icons.receipt_long_rounded,
                              color: AppTheme.amber,
                            ),
                            TabSpec(
                              label: t('fees.tabPayments'),
                              icon: Icons.payments_rounded,
                              color: AppTheme.blue,
                            ),
                            TabSpec(
                              label: t('fees.tabReceipts'),
                              icon: Icons.verified_rounded,
                              color: AppTheme.green,
                            ),
                          ],
                        ),
                      ],
                      if (tab == 0)
                        _BillsTab(desk: desk)
                      else if (tab == 1)
                        _PaymentsTab(desk: desk, onChanged: _reload, onDeclare: () => _declare(desk))
                      else
                        _ReceiptsTab(desk: desk),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _declare(_Desk desk) async {
    final options = desk.options;
    if (options == null) return;

    final sent = await showAppSheet<bool>(
      context,
      builder: (_) => _DeclareSheet(
        options: options,
        invoices: desk.summary.invoices,
        children: desk.children,
      ),
    );
    if (!mounted || sent != true) return;
    _reload();
    showNote(context, t('dec.sent'));
  }
}

class _Desk {
  const _Desk({
    required this.summary,
    this.options,
    this.payments = const [],
    this.paymentsTotal = 0,
    this.receipts = const [],
    this.receiptsTotal = 0,
    this.children = const [],
  });

  final FeeSummary summary;

  final PaymentOptions? options;

  final List<DeclaredPayment> payments;
  final int paymentsTotal;
  final List<PaymentReceipt> receipts;
  final int receiptsTotal;
  final List<Child> children;

  bool get moneyDesk => options != null;
  bool get canDeclare => options?.allowSelfDeclare ?? false;

  int get awaitingIqd =>
      payments.where((p) => p.awaiting).fold(0, (sum, p) => sum + p.amountIqd);
}

class _BillsTab extends StatelessWidget {
  const _BillsTab({required this.desk});

  final _Desk desk;

  @override
  Widget build(BuildContext context) {
    final f = desk.summary;
    final settled = f.outstandingIqd <= 0;
    final instructions = desk.options?.instructions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: kCardGap),
        _BalanceCard(summary: f),

        if (desk.awaitingIqd > 0) ...[
          const SizedBox(height: kCardGap),
          NoticeBanner(
            icon: Icons.hourglass_top_rounded,
            title: t('fees.declaredTitle'),
            body: tn('fees.declaredBody', iqd(desk.awaitingIqd)),
            color: AppTheme.amber,
          ),
        ],

        if (!settled) ...[
          Heading(t('fees.howToPay')),

          if (instructions != null) ...[
            Card16(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip36(icon: Icons.info_rounded, color: Role.parent.tint),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('fees.schoolSays'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          instructions,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),
          ],

          Card16(
            padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Way(
                  icon: Icons.payments_rounded,
                  colour: AppTheme.green,
                  title: t('fees.cash'),
                  body: t('fees.cashBody'),
                ),
                Divider(height: 1, color: AppTheme.border),
                _Way(
                  icon: Icons.account_balance_rounded,
                  colour: AppTheme.blue,
                  title: t('fees.transfer'),
                  body: t('fees.transferBody'),
                ),
                Divider(height: 1, color: AppTheme.border),
                _Way(
                  icon: Icons.directions_bus_rounded,
                  colour: AppTheme.violet,
                  title: t('fees.driver'),
                  body: t('fees.driverBody'),
                ),
              ],
            ),
          ),
        ],

        Heading(t('fees.yourBills')),
        if (f.invoices.isEmpty)
          _Nothing(icon: Icons.receipt_long_rounded, text: t('fees.nothingBilled'))
        else
          for (var i = 0; i < f.invoices.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == f.invoices.length - 1 ? 0 : kCardGap,
              ),
              child: _InvoiceCard(
                invoice: f.invoices[i],
                canOpen: desk.moneyDesk && f.invoices[i].status != 'DRAFT',
              ),
            ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final FeeSummary summary;

  @override
  Widget build(BuildContext context) {
    final settled = summary.outstandingIqd <= 0;
    final overdue = summary.overdueIqd > 0;

    final colour = settled
        ? AppTheme.green
        : overdue
            ? AppTheme.rose
            : AppTheme.amber;
    final ground = settled
        ? AppTheme.greenSoft
        : overdue
            ? AppTheme.roseSoft
            : AppTheme.amberSoft;

    final days = summary.daysUntilDue;
    final when = settled
        ? t('fees.paid')
        : overdue
            ? t('fees.overdue')
            : days == null || days <= 0
                ? t('fees.dueNow')
                : days == 1
                    ? t('fees.dueTomorrow')
                    : tn('fees.dueInDays', days);

    final line = settled
        ? t('fees.upToDate')
        : overdue
            ? tn('fees.overdueAmount', iqd(summary.overdueIqd))
            : summary.dueAt == null
                ? ''
                : longDate(summary.dueAt);

    return Card16(
      color: ground,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(
                icon: settled
                    ? Icons.check_circle_rounded
                    : Icons.account_balance_wallet_rounded,
                color: colour,
                background: AppTheme.surface,
                size: 46,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('fees.outstanding'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          settled
                              ? t('fees.nothingOwed')
                              : iqd(summary.outstandingIqd),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1.1,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(height: 1, color: colour.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Pill(when, color: colour, background: AppTheme.surface),
              if (line.isNotEmpty) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Way extends StatelessWidget {
  const _Way({
    required this.icon,
    required this.colour,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip36(icon: icon, color: colour),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.canOpen});

  final Invoice2 invoice;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    final paid = invoice.balanceIqd <= 0;
    final colour = paid
        ? AppTheme.green
        : invoice.overdue
            ? AppTheme.rose
            : AppTheme.amber;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip36(icon: Icons.receipt_long_rounded, color: colour),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${shortDate(invoice.periodStart)} – ${longDate(invoice.periodEnd)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.serial,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(
                paid
                    ? t('fees.paid')
                    : invoice.overdue
                        ? t('fees.overdue')
                        : humanise(invoice.status),
                color: colour,
              ),
            ],
          ),

          if (invoice.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 11),
            for (var i = 0; i < invoice.lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 7),
              _Line(line: invoice.lines[i]),
            ],
          ],

          const SizedBox(height: 11),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Text(
                  t('fees.total'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                iqd(invoice.totalIqd),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),

          if (!paid) ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(
                    invoice.overdue
                        ? Icons.error_outline_rounded
                        : Icons.event_rounded,
                    size: 16,
                    color: colour,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('fees.stillOwed'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colour,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tn('fees.dueOn', longDate(invoice.dueAt)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    iqd(invoice.balanceIqd),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: colour,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (canOpen) ...[
            const SizedBox(height: 11),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _DocButton(
                label: t('fees.openBill'),
                icon: Icons.picture_as_pdf_rounded,
                colour: Role.parent.tint,
                fetch: () => ParentApi.instance.invoicePdf(invoice.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final InvoiceLine2 line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            line.studentName != null
                ? '${line.description} — ${line.studentName}'
                : line.description,
            style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          iqd(line.amountIqd),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: AppTheme.text,
          ),
        ),
      ],
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({
    required this.desk,
    required this.onChanged,
    required this.onDeclare,
  });

  final _Desk desk;
  final VoidCallback onChanged;
  final VoidCallback onDeclare;

  @override
  Widget build(BuildContext context) {
    final targets = _Target.listFor(desk.summary.invoices, desk.children);
    final canDeclare = desk.canDeclare && targets.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: kCardGap),

        if (canDeclare) ...[
          BigButton(
            label: t('pay.tell'),
            color: Role.parent.tint,
            onPressed: onDeclare,
          ),
          const SizedBox(height: kCardGap),
        ] else if (!desk.canDeclare) ...[
          NoticeBanner(
            icon: Icons.info_rounded,
            title: t('pay.notTakenTitle'),
            body: t('pay.notTakenBody'),
            color: AppTheme.blue,
          ),
          const SizedBox(height: kCardGap),
        ],

        if (desk.payments.isEmpty)
          _Nothing(icon: Icons.payments_rounded, text: t('pay.none'))
        else ...[
          for (var i = 0; i < desk.payments.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == desk.payments.length - 1 ? 0 : kCardGap,
              ),
              child: _PaymentCard(payment: desk.payments[i], onChanged: onChanged),
            ),
          if (desk.paymentsTotal > desk.payments.length)
            _More(shown: desk.payments.length),
        ],
      ],
    );
  }
}

class _Target {
  const _Target({
    this.invoiceId,
    this.studentId,
    required this.label,
    required this.sub,
    required this.icon,
    this.amountIqd,
  });

  final String? invoiceId;
  final String? studentId;
  final String label;
  final String sub;
  final IconData icon;

  final int? amountIqd;

  String get id => invoiceId ?? studentId ?? '';

  static List<_Target> listFor(List<Invoice2> invoices, List<Child> children) => [
        for (final invoice in invoices)
          if (invoice.balanceIqd > 0)
            _Target(
              invoiceId: invoice.id,
              label: tn('pay.forBill', invoice.serial),
              sub: iqd(invoice.balanceIqd),
              icon: Icons.receipt_long_rounded,
              amountIqd: invoice.balanceIqd,
            ),
        for (final child in children)
          _Target(
            studentId: child.studentId,
            label: child.name,
            sub: child.className,
            icon: Icons.person_rounded,
          ),
      ];
}

class _PaymentCard extends StatefulWidget {
  const _PaymentCard({required this.payment, required this.onChanged});

  final DeclaredPayment payment;
  final VoidCallback onChanged;

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final (colour, word) = _statusOf(p);
    final receipt = p.receipt;
    final refusal = p.refusal;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip36(icon: _methodIcon(p.method), color: colour),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      iqd(p.amountIqd),
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
                      '${_methodName(p.method)}  •  ${longDate(p.when)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(word, color: colour),
            ],
          ),

          if (p.invoiceSerial != null || p.studentName != null || p.reference != null) ...[
            const SizedBox(height: 10),
            if (p.invoiceSerial != null)
              _Detail(
                icon: Icons.receipt_long_rounded,
                text: tn('pay.forBill', p.invoiceSerial!),
              ),
            if (p.studentName != null)
              _Detail(icon: Icons.person_rounded, text: tn('pay.forChild', p.studentName!)),
            if (p.reference != null && p.reference!.isNotEmpty)
              _Detail(icon: Icons.tag_rounded, text: tn('pay.reference', p.reference!)),
          ],

          if (refusal != null) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                refusal,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                  color: colour,
                ),
              ),
            ),
          ],

          if (receipt != null || p.awaiting) ...[
            const SizedBox(height: 11),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 11),
            Row(
              children: [
                if (receipt != null)
                  _DocButton(
                    label: t('pay.receipt'),
                    icon: Icons.verified_rounded,
                    colour: AppTheme.green,
                    fetch: () => ParentApi.instance.receiptPdf(receipt.id),
                  ),
                if (receipt != null && p.awaiting) const SizedBox(width: 9),
                if (p.awaiting)
                  _MiniButton(
                    label: t('pay.takeBack'),
                    icon: Icons.undo_rounded,
                    colour: AppTheme.rose,
                    busy: _busy,
                    onTap: _takeBack,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _takeBack() async {
    final yes = await confirmDialog(
      context,
      icon: Icons.undo_rounded,
      tone: AppTheme.rose,
      title: t('pay.takeBackTitle'),
      body: t('pay.takeBackBody'),
      confirmLabel: t('pay.takeBack'),
      confirmIcon: Icons.undo_rounded,
    );
    if (!yes || !mounted) return;

    setState(() => _busy = true);
    try {
      await ParentApi.instance.withdrawPayment(widget.payment.id);
      if (!mounted) return;
      widget.onChanged();
      showNote(context, t('pay.takenBack'));
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ReceiptsTab extends StatelessWidget {
  const _ReceiptsTab({required this.desk});

  final _Desk desk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: kCardGap),
        if (desk.receipts.isEmpty)
          _Nothing(icon: Icons.verified_rounded, text: t('rec.none'))
        else ...[
          for (var i = 0; i < desk.receipts.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == desk.receipts.length - 1 ? 0 : kCardGap,
              ),
              child: _ReceiptCard(receipt: desk.receipts[i]),
            ),
          if (desk.receiptsTotal > desk.receipts.length)
            _More(shown: desk.receipts.length),
        ],
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt});

  final PaymentReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip36(icon: Icons.verified_rounded, color: AppTheme.green),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.serial,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tn('rec.issued', longDate(receipt.issuedAt)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                iqd(receipt.amountIqd),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),

          if (receipt.studentName != null || receipt.invoiceSerial != null) ...[
            const SizedBox(height: 10),
            if (receipt.studentName != null)
              _Detail(
                icon: Icons.person_rounded,
                text: tn('pay.forChild', receipt.studentName!),
              ),
            if (receipt.invoiceSerial != null)
              _Detail(
                icon: Icons.receipt_long_rounded,
                text: tn('pay.forBill', receipt.invoiceSerial!),
              ),
          ],

          const SizedBox(height: 11),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 11),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _DocButton(
              label: t('rec.open'),
              icon: Icons.picture_as_pdf_rounded,
              colour: AppTheme.green,
              fetch: () => ParentApi.instance.receiptPdf(receipt.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeclareSheet extends StatefulWidget {
  const _DeclareSheet({
    required this.options,
    required this.invoices,
    required this.children,
  });

  final PaymentOptions options;
  final List<Invoice2> invoices;
  final List<Child> children;

  @override
  State<_DeclareSheet> createState() => _DeclareSheetState();
}

class _DeclareSheetState extends State<_DeclareSheet> {
  static const _minIqd = 250;
  static const _maxIqd = 500000000;
  static const _maxReference = 120;
  static const _maxNote = 1000;

  late final List<_Target> _targets;
  late final List<String> _methods;

  late final String _idempotencyKey;

  _Target? _target;
  String? _method;
  DateTime? _paidAt;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  String? _proofAssetId;
  bool _uploadingProof = false;

  bool get _proofRequired =>
      _method == 'BANK_TRANSFER' && widget.options.requireProofForTransfer;

  @override
  void initState() {
    super.initState();
    _targets = _Target.listFor(widget.invoices, widget.children);
    _methods = widget.options.usableMethods;
    _method = _methods.isEmpty ? null : _methods.first;
    _idempotencyKey = _nonce();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  static String _nonce() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final salt = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'ksp-$now-$salt';
  }

  int? get _amountIqd {
    final digits = _amount.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  String? get _amountProblem {
    final amount = _amountIqd;
    if (amount == null) return null;
    if (amount < _minIqd) return t('dec.amountFloor');
    if (amount > _maxIqd) return t('dec.amountCeiling');
    return null;
  }

  bool get _ready =>
      _target != null &&
      _method != null &&
      _amountIqd != null &&
      _amountProblem == null &&
      !(_proofRequired && _proofAssetId == null) &&
      !_uploadingProof;

  void _choose(_Target target) {
    if (_amount.text.trim().isEmpty && target.amountIqd != null) {
      _amount.text = '${target.amountIqd}';
    }
    setState(() => _target = target);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await pickDate(
      context,
      initial: _paidAt ?? now,
      first: DateTime(now.year - 1, now.month, now.day),
      last: now,
      tint: Role.parent.tint,
      title: t('dec.when'),
    );
    if (picked == null) return;
    setState(() => _paidAt = picked);
  }

  Future<void> _attachProof() async {
    final source = await pickOne<ImageSource>(
      context,
      tint: Role.parent.tint,
      title: t('dec.proofAdd'),
      options: [
        PickOption(
          value: ImageSource.camera,
          label: t('dec.proofPhotograph'),
          icon: Icons.photo_camera_rounded,
        ),
        PickOption(
          value: ImageSource.gallery,
          label: t('dec.proofFromPhone'),
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
      final shot = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 80,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      final id = await ParentApi.instance.uploadFile(
        bytes: bytes,
        filename: 'slip.jpg',
        mime: 'image/jpeg',
        kind: 'PAYMENT_PROOF',
        studentId: _target?.studentId,
        capturedAt: DateTime.now(),
      );
      if (mounted) setState(() => _proofAssetId = id);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = t('dec.proofFailed'));
    } finally {
      if (mounted) setState(() => _uploadingProof = false);
    }
  }

  Future<void> _send() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentApi.instance.declarePayment(
        amountIqd: _amountIqd!,
        method: _method!,
        idempotencyKey: _idempotencyKey,
        invoiceId: _target!.invoiceId,
        studentId: _target!.studentId,
        paidAt: _paidAt,
        reference: _reference.text,
        notes: _note.text,
        proofAssetId: _proofAssetId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final problem = _amountProblem;

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
                t('dec.title'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                t('dec.body'),
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              _Label(t('dec.what')),
              const SizedBox(height: 4),
              Text(
                t('dec.whatHint'),
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 9),
              for (final target in _targets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PickRow(
                    label: target.label,
                    sub: target.sub,
                    icon: target.icon,
                    on: _target?.id == target.id,
                    onTap: () => _choose(target),
                  ),
                ),
              const SizedBox(height: 10),

              _Label(t('dec.amount')),
              const SizedBox(height: 8),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: t('dec.amountHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              if (problem != null) ...[
                const SizedBox(height: 6),
                Text(problem, style: TextStyle(fontSize: 11.5, color: AppTheme.rose)),
              ],
              const SizedBox(height: 18),

              _Label(t('dec.how')),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in _methods)
                    _MethodChip(
                      label: _methodName(method),
                      icon: _methodIcon(method),
                      on: method == _method,
                      onTap: () => setState(() => _method = method),
                    ),
                ],
              ),

              const SizedBox(height: 14),
              _ProofAttachment(
                assetId: _proofAssetId,
                busy: _uploadingProof,
                required: _proofRequired,
                onPick: _attachProof,
                onClear: () => setState(() => _proofAssetId = null),
              ),
              const SizedBox(height: 18),

              _Label(t('dec.when')),
              const SizedBox(height: 8),
              _DateField(value: _paidAt ?? DateTime.now(), onTap: _pickDate),
              const SizedBox(height: 18),

              _Label(t('dec.reference')),
              const SizedBox(height: 8),
              TextField(
                controller: _reference,
                maxLength: _maxReference,
                decoration: InputDecoration(
                  hintText: t('dec.referenceHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              _Label(t('dec.note')),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: _maxNote,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: t('dec.noteHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: TextStyle(fontSize: 12, color: AppTheme.rose)),
              ],
              const SizedBox(height: 12),

              BigButton(
                label: t('dec.send'),
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

class _ProofAttachment extends StatelessWidget {
  const _ProofAttachment({
    required this.assetId,
    required this.busy,
    required this.required,
    required this.onPick,
    required this.onClear,
  });

  final String? assetId;
  final bool busy;
  final bool required;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final attached = assetId != null;

    return InkWell(
      onTap: busy ? null : (attached ? onClear : onPick),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: attached ? tint.withValues(alpha: 0.08) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: attached ? tint.withValues(alpha: 0.45) : AppTheme.border,
          ),
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
                    ? t('dec.proofUploading')
                    : attached
                        ? t('dec.proofAttached')
                        : required
                            ? t('dec.proofNeeded')
                            : t('dec.proofAdd'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: attached ? FontWeight.w600 : FontWeight.w500,
                  color: attached ? tint : AppTheme.text,
                ),
              ),
            ),
            if (attached && !busy)
              Text(
                t('dec.proofRemove'),
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

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
              maxLines: 1,
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

class _DocButton extends StatefulWidget {
  const _DocButton({
    required this.label,
    required this.icon,
    required this.colour,
    required this.fetch,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final Future<StoredDocument> Function() fetch;

  @override
  State<_DocButton> createState() => _DocButtonState();
}

class _DocButtonState extends State<_DocButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final doc = await widget.fetch();
      final opened = await launchUrl(
        Uri.parse(doc.url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        showNote(context, t('fees.docFailed'), bad: true);
        return;
      }
      if (doc.latinOnly && AppLocale.current.value != Lang.en) {
        showNote(context, t('fees.docLatin'));
      }
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } catch (_) {
      if (mounted) showNote(context, t('fees.docFailed'), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MiniButton(
      label: widget.label,
      icon: widget.icon,
      colour: widget.colour,
      busy: _busy,
      onTap: _open,
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.label,
    required this.sub,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final String sub;
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: AppTheme.dark ? 0.18 : 0.08) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: on ? tint : AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: on ? tint : AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            if (on) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 19, color: tint),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
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

class _Nothing extends StatelessWidget {
  const _Nothing({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppTheme.textFaint),
          const SizedBox(height: 11),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _More extends StatelessWidget {
  const _More({required this.shown});

  final int shown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        tn('pay.showingRecent', shown),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
      ),
    );
  }
}

IconData _methodIcon(String method) => switch (method.toUpperCase()) {
      'CASH' => Icons.payments_rounded,
      'BANK_TRANSFER' => Icons.account_balance_rounded,
      'FIB' || 'FASTPAY' || 'ZAINCASH' || 'ASIAHAWALA' => Icons.smartphone_rounded,
      _ => Icons.more_horiz_rounded,
    };

String _methodName(String method) => switch (method.toUpperCase()) {
      'CASH' => t('pay.mCash'),
      'BANK_TRANSFER' => t('pay.mBankTransfer'),
      'FIB' => t('pay.mFib'),
      'FASTPAY' => t('pay.mFastpay'),
      'ZAINCASH' => t('pay.mZaincash'),
      'ASIAHAWALA' => t('pay.mAsiahawala'),
      'OTHER' => t('pay.mOther'),
      _ => humanise(method),
    };

(Color, String) _statusOf(DeclaredPayment payment) {
  if (payment.withdrawnByFamily) return (AppTheme.textMuted, t('pay.withdrawn'));
  return switch (payment.status) {
    'PENDING_CONFIRMATION' => (AppTheme.amber, t('pay.awaiting')),
    'CONFIRMED' => (AppTheme.green, t('pay.confirmed')),
    'REJECTED' => (AppTheme.rose, t('pay.rejected')),
    'REVERSED' => (AppTheme.rose, t('pay.reversed')),
    'FAILED' => (AppTheme.rose, t('pay.failed')),
    'WITHDRAWN' => (AppTheme.textMuted, t('pay.withdrawn')),
    _ => (AppTheme.textMuted, humanise(payment.status)),
  };
}
