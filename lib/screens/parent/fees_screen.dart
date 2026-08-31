import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// What the household owes, and when.
///
/// One household, one bill — siblings are on the same invoice, because that is
/// how a school here actually charges and splitting it per child would produce
/// two demands for one payment.
///
/// The money is the headline and everything under it is support. The amount is
/// the largest thing on the page, the pill beside it answers "by when" without
/// anybody reading a date, and the colour of both says whether the household is
/// late — the three questions a parent opened this screen with, in that order.
class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('fees.title')),
            Expanded(
              child: Loader<FeeSummary>(
                tint: Role.parent.tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () => ParentApi.instance.fees(),
                builder: (context, f) {
                  final settled = f.outstandingIqd <= 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BalanceCard(summary: f),

                      if (!settled) ...[
                        Heading(t('fees.howToPay')),
                        // Written out rather than left to a parent to ask at the
                        // gate. "How do I pay" is the single most common call the
                        // office takes about fees.
                        //
                        // The rows are the kit's list row — the same chip, gap
                        // and type as every other list of options in the app —
                        // with the one difference that matters here: the body
                        // is allowed to wrap, because a payment instruction cut
                        // off at one line is not an instruction.
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
                        const _NothingBilled()
                      else
                        for (var i = 0; i < f.invoices.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == f.invoices.length - 1 ? 0 : kCardGap,
                            ),
                            child: _InvoiceCard(invoice: f.invoices[i]),
                          ),
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
}

/* ---------------------------------------------------------------------------
 * What is owed
 * ------------------------------------------------------------------------- */

/// The one figure the screen exists for.
///
/// The amount is given the whole width of the card rather than a column beside
/// a badge, which is what kept it down at heading size before: nothing else on
/// this card competes with it. The timing sits under a hairline in the status
/// colour — a pill for the deadline, the date itself in words after it — so
/// "how much" and "by when" are read in two movements rather than one sentence.
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

    // The deadline as a badge. Nothing here is calculated from a date the API
    // did not send: the countdown is the server's own daysUntilDue, and when it
    // did not send one the pill falls back to saying the bill is due, not to
    // guessing a day.
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

    // The sentence beside it. Late, and it says how much of the balance is
    // late; on time, it names the day.
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
                    // Scaled down rather than wrapped or clipped: a household
                    // owing eight figures still gets one line, and every other
                    // amount is drawn at full size.
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

/* ---------------------------------------------------------------------------
 * How to pay
 * ------------------------------------------------------------------------- */

/// One way of settling the bill: the kit's list row, with a body that wraps.
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

/* ---------------------------------------------------------------------------
 * The bills
 * ------------------------------------------------------------------------- */

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice2 invoice;

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
          // The same head as every other list row in the app: a chip in the
          // status colour, the period and its serial, the status on the right.
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

          // What is still owed on this bill, and the day it is wanted, held
          // together on a tinted ground. Two grey rows one under the other made
          // the balance — the only line on the card anybody has to act on —
          // look like a second subtotal.
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
        ],
      ),
    );
  }
}

/// One charge on a bill: what it is for, and what it costs.
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

/// Nothing billed yet — the app's empty state, inside the card the bills would
/// have filled, rather than a lone grey sentence.
class _NothingBilled extends StatelessWidget {
  const _NothingBilled();

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 30, color: AppTheme.textFaint),
          const SizedBox(height: 11),
          Text(
            t('fees.nothingBilled'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
