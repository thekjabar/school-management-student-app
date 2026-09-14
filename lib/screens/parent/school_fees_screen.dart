import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import 'payment_notices.dart';

class SchoolFeesScreen extends StatelessWidget {
  const SchoolFeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PaymentsDesk<SchoolFeesOverview>(
      title: t('schoolFees.title'),
      payee: PaymentPayee.school,
      loadOverview: ParentApi.instance.schoolFees,
      isEmpty: (overview) => overview.children.isEmpty,
      builder: (context, overview, notices, reload) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            t('schoolFees.intro'),
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
          for (final child in overview.children)
            _ChildSection(
              key: ValueKey('schoolFees.section.${child.studentId}'),
              child: child,
              methods: overview.methods,
              notices: [
                for (final n in notices)
                  if (n.studentId == child.studentId && n.schoolId == child.schoolId) n,
              ],
              onChanged: reload,
            ),
        ],
      ),
    );
  }
}

class _ChildSection extends StatelessWidget {
  const _ChildSection({
    super.key,
    required this.child,
    required this.methods,
    required this.notices,
    required this.onChanged,
  });

  final SchoolFeeChild child;
  final List<String> methods;
  final List<PaymentNotice> notices;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final year = child.year;
    final sub = [
      child.school,
      if (child.allowsAppPayment && year != null && year.name.isNotEmpty) tn('schoolFees.year', year.name),
    ].where((s) => s.isNotEmpty).join('  •  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        ChildPaymentsHeading(name: child.childName, sub: sub),
        const SizedBox(height: 10),
        if (!child.allowsAppPayment)
          SchoolFeesNotInAppCard(child: child)
        else ...[
          SchoolFeeStatementCard(child: child),
          if (year != null) ...[
            const SizedBox(height: kCardGap + 3),
            BigButton(
              key: ValueKey('schoolFees.pay.${child.studentId}'),
              label: t('schoolFees.paidButton'),
              color: Role.parent.tint,
              onPressed: () => tellPayment(
                context,
                payee: PaymentPayee.school,
                target: NoticeTarget.of(child),
                methods: methods,
                onChanged: onChanged,
                suggestedIqd: child.statement?.nextDueIqd,
              ),
            ),
          ],
        ],
        if (child.allowsAppPayment || notices.isNotEmpty)
          NoticeHistory(
            payee: PaymentPayee.school,
            childName: child.childName,
            notices: notices,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class SchoolFeesNotInAppCard extends StatelessWidget {
  const SchoolFeesNotInAppCard({super.key, required this.child});

  final SchoolFeeChild child;

  @override
  Widget build(BuildContext context) {
    return Card16(
      key: ValueKey('schoolFees.notInApp.${child.studentId}'),
      color: AppTheme.blue.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip36(icon: Icons.storefront_rounded, color: AppTheme.blue, background: AppTheme.surface),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('schoolFees.notInAppTitle'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  child.notInAppText(),
                  style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SchoolFeeStatementCard extends StatelessWidget {
  const SchoolFeeStatementCard({super.key, required this.child});

  final SchoolFeeChild child;

  @override
  Widget build(BuildContext context) {
    final statement = child.statement;
    if (child.year == null || statement == null) {
      return _Plain(text: t('schoolFees.noYear'));
    }
    if (!statement.hasPlan && !statement.exempt) {
      return _Plain(text: tv('schoolFees.noPlan', {'name': child.childName}));
    }

    final settled = statement.balanceIqd <= 0;
    final overdue = statement.overdueIqd > 0;
    final colour = settled
        ? AppTheme.green
        : overdue
            ? AppTheme.rose
            : AppTheme.amber;
    final next = statement.nextDueOn;

    return Card16(
      key: ValueKey('schoolFees.statement.${child.studentId}'),
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Chip36(
                icon: settled ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                color: colour,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('schoolFees.balance'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          settled ? t('schoolFees.settled') : iqd(statement.balanceIqd),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            height: 1.1,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (statement.exempt) ...[
                const SizedBox(width: 8),
                Pill(t('schoolFees.exempt'), color: AppTheme.green),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 10),
          _Figure(label: t('schoolFees.due'), amount: statement.dueIqd),
          if (statement.discountIqd > 0) _Figure(label: t('schoolFees.discount'), amount: statement.discountIqd),
          _Figure(label: t('schoolFees.paid'), amount: statement.paidIqd, colour: AppTheme.green),
          if (statement.pendingIqd > 0)
            _Figure(label: t('schoolFees.pending'), amount: statement.pendingIqd, colour: AppTheme.amber),
          if (statement.overdueIqd > 0)
            _Figure(label: t('schoolFees.overdue'), amount: statement.overdueIqd, colour: AppTheme.rose),
          if (next != null && statement.nextDueIqd != null && !settled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 16, color: colour),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      tv('schoolFees.nextDue', {'date': longDate(next)}),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colour),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    iqd(statement.nextDueIqd),
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: colour),
                  ),
                ],
              ),
            ),
          ],
          if (statement.instalments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              t('schoolFees.instalments'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.text),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < statement.instalments.length; i++)
              _InstalmentRow(
                key: ValueKey('schoolFees.instalment.${child.studentId}.$i'),
                number: i + 1,
                line: statement.instalments[i],
              ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.amount, this.colour});

  final String label;
  final int amount;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
          ),
          const SizedBox(width: 10),
          Text(
            iqd(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colour ?? AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstalmentRow extends StatelessWidget {
  const _InstalmentRow({super.key, required this.number, required this.line});

  final int number;
  final FeeInstalment line;

  @override
  Widget build(BuildContext context) {
    final (colour, word) = switch (line.state) {
      InstalmentState.paid => (AppTheme.green, t('schoolFees.statePaid')),
      InstalmentState.partial => (AppTheme.blue, t('schoolFees.statePartial')),
      InstalmentState.due => (AppTheme.amber, t('schoolFees.stateDue')),
      InstalmentState.overdue => (AppTheme.rose, t('schoolFees.stateOverdue')),
    };
    final showRemaining = line.state == InstalmentState.partial || line.state == InstalmentState.overdue;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tn('schoolFees.instalment', number),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    tn('schoolFees.dueOn', longDate(line.dueOn)),
                    if (showRemaining) tn('schoolFees.remaining', iqd(line.remainingIqd)),
                  ].join('  •  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                iqd(line.payableIqd),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.text),
              ),
              const SizedBox(height: 3),
              Pill(word, color: colour),
            ],
          ),
        ],
      ),
    );
  }
}

class _Plain extends StatelessWidget {
  const _Plain({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
      ),
    );
  }
}
