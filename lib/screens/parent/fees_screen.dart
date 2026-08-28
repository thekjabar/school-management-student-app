import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../i18n/strings.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';

/// What the household owes, and when.
///
/// One household, one bill — siblings are on the same invoice, because that is
/// how a school here actually charges and splitting it per child would produce
/// two demands for one payment.
class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(t('fees.title')),
        backgroundColor: Role.parent.wash,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Loader<FeeSummary>(
        tint: Role.parent.tint,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        load: () => ParentApi.instance.fees(),
        builder: (context, f) {
          final settled = f.outstandingIqd <= 0;
          final late = f.overdueIqd > 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card16(
                color: settled
                    ? AppTheme.greenSoft
                    : late
                        ? AppTheme.roseSoft
                        : AppTheme.amberSoft,
                child: Row(
                  children: [
                    Chip36(
                      icon: settled ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                      color: settled
                          ? AppTheme.green
                          : late
                              ? AppTheme.rose
                              : AppTheme.amber,
                      background: AppTheme.surface,
                      size: 44,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            settled ? t('fees.nothingOwed') : iqd(f.outstandingIqd),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            settled
                                ? t('fees.upToDate')
                                : late
                                    ? tn('fees.overdueAmount', iqd(f.overdueIqd))
                                    : f.dueAt == null
                                        ? t('fees.dueNow')
                                        : tn('fees.dueOn', longDate(f.dueAt)) +
                                            (f.daysUntilDue != null ? tn('fees.inDays', f.daysUntilDue!) : ''),
                            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (!settled) ...[
                Heading(t('fees.howToPay')),
                Card16(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Written out rather than left to a parent to ask at the
                      // gate. "How do I pay" is the single most common call the
                      // office takes about fees.
                      _Way(
                        icon: Icons.payments_rounded,
                        title: t('fees.cash'),
                        body: t('fees.cashBody'),
                      ),
                      Divider(height: 22, color: AppTheme.border),
                      _Way(
                        icon: Icons.account_balance_rounded,
                        title: t('fees.transfer'),
                        body: t('fees.transferBody'),
                      ),
                      Divider(height: 22, color: AppTheme.border),
                      _Way(
                        icon: Icons.directions_bus_rounded,
                        title: t('fees.driver'),
                        body: t('fees.driverBody'),
                      ),
                    ],
                  ),
                ),
              ],

              Heading(t('fees.yourBills')),
              if (f.invoices.isEmpty)
                Card16(
                  child: Text(
                    t('fees.nothingBilled'),
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                )
              else
                ...f.invoices.map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InvoiceCard(invoice: i),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _Way extends StatelessWidget {
  const _Way({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip36(icon: icon, color: AppTheme.violet),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${shortDate(invoice.periodStart)} – ${longDate(invoice.periodEnd)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.serial,
                      style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                    ),
                  ],
                ),
              ),
              Pill(
                paid ? t('fees.paid') : invoice.overdue ? t('fees.overdue') : humanise(invoice.status),
                color: colour,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 12),
          for (final line in invoice.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.studentName != null
                          ? '${line.description} — ${line.studentName}'
                          : line.description,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  Text(
                    iqd(line.amountIqd),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(t('fees.total'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              Text(
                iqd(invoice.totalIqd),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (!paid) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(t('fees.stillOwed'), style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                ),
                Text(
                  iqd(invoice.balanceIqd),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colour),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              tn('fees.dueOn', longDate(invoice.dueAt)),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}
