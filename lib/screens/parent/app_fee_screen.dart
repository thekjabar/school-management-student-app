import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import 'payment_notices.dart';

class AppFeeScreen extends StatelessWidget {
  const AppFeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PaymentsDesk<PackageOverview>(
      title: t('appFee.title'),
      payee: PaymentPayee.ksp,
      loadOverview: ParentApi.instance.packageOverview,
      isEmpty: (overview) => overview.children.isEmpty,
      builder: (context, overview, notices, reload) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            t('appFee.intro'),
            style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
          ),
          for (final child in overview.children) ...[
            const SizedBox(height: 18),
            PackageChildCard(
              child: child,
              onPaid: () => tellPayment(
                context,
                payee: PaymentPayee.ksp,
                target: NoticeTarget.of(child),
                methods: overview.methods,
                onChanged: reload,
              ),
            ),
            NoticeHistory(
              payee: PaymentPayee.ksp,
              childName: child.childName,
              notices: [
                for (final n in notices)
                  if (n.studentId == child.studentId) n,
              ],
              onChanged: reload,
            ),
          ],
        ],
      ),
    );
  }
}

class PackageChildCard extends StatelessWidget {
  const PackageChildCard({super.key, required this.child, required this.onPaid});

  final PackageChild child;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    final (colour, word) = switch (child.status) {
      PackageStatus.active => (AppTheme.green, t('appFee.statusActive')),
      PackageStatus.startsLater => (AppTheme.blue, t('appFee.statusStartsLater')),
      PackageStatus.expired => (AppTheme.rose, t('appFee.statusExpired')),
      PackageStatus.none => (AppTheme.textMuted, t('appFee.statusNone')),
    };
    final waiting = child.pendingNotices.length;
    final line = _statusLine(child);

    return Card16(
      key: ValueKey('appFee.child.${child.studentId}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: ChildPaymentsHeading(name: child.childName, sub: child.school)),
              const SizedBox(width: 8),
              Pill(word, color: colour),
            ],
          ),
          if (line.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              line,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
            ),
          ],
          if (waiting > 0) ...[
            const SizedBox(height: 9),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Pill(tn('appFee.waiting', waiting), color: AppTheme.amber),
            ),
          ],
          const SizedBox(height: kCardGap + 3),
          BigButton(
            key: ValueKey('appFee.pay.${child.studentId}'),
            label: t('appFee.paidButton'),
            color: Role.parent.tint,
            onPressed: onPaid,
          ),
        ],
      ),
    );
  }

  static String _statusLine(PackageChild child) {
    final since = child.since;
    final until = child.until;
    return switch (child.status) {
      PackageStatus.active when since != null && until != null =>
        tv('appFee.activeLine', {'from': longDate(since), 'until': longDate(until)}),
      PackageStatus.active when since != null => tv('appFee.activeOpenLine', {'from': longDate(since)}),
      PackageStatus.active => '',
      PackageStatus.startsLater when since != null => tv('appFee.startsLine', {'from': longDate(since)}),
      PackageStatus.startsLater => '',
      PackageStatus.expired when until != null => tv('appFee.expiredLine', {'until': longDate(until)}),
      PackageStatus.expired => t('appFee.expiredNoDate'),
      PackageStatus.none => t('appFee.noneLine'),
    };
  }
}
