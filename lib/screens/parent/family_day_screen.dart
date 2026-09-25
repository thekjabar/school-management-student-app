import 'package:flutter/material.dart';

import '../../api/family_day.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/format.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

String clashSentence(FamilyClash c) => tv(
      c.kind == ClashKind.pickup ? 'familyDay.clashPickup' : 'familyDay.clashDropoff',
      {'a': c.first.firstName, 'b': c.second.firstName, 'n': c.minutesApart},
    );

class FamilyDayScreen extends StatefulWidget {
  const FamilyDayScreen({super.key});

  @override
  State<FamilyDayScreen> createState() => _FamilyDayScreenState();
}

class _FamilyDayScreenState extends State<FamilyDayScreen> {
  bool _tomorrow = false;
  final _loaderKey = GlobalKey<LoaderState<List<FamilyChildDay>>>();

  DateTime get _day {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _tomorrow ? today.add(const Duration(days: 1)) : today;
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
            ScreenHeader(title: t('familyDay.title')),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 10),
              child: PillTabs(
                tabs: [TabSpec(label: t('familyDay.today')), TabSpec(label: t('familyDay.tomorrow'))],
                index: _tomorrow ? 1 : 0,
                tint: tint,
                onChanged: (i) {
                  setState(() => _tomorrow = i == 1);
                  _loaderKey.currentState?.reload();
                },
              ),
            ),
            Expanded(
              child: Loader<List<FamilyChildDay>>(
                key: _loaderKey,
                tint: tint,
                padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                load: () => loadFamilyDay(_day),
                isEmpty: (rows) => rows.isEmpty,
                empty: t('familyDay.none'),
                builder: (context, children) {
                  final clashes = familyClashes(children);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in clashes) ...[
                        Card16(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Chip36(icon: Icons.warning_amber_rounded, color: AppTheme.amber),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      clashSentence(c),
                                      style: TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w700, color: AppTheme.text),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      t('familyDay.fix'),
                                      style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kCardGap),
                      ],
                      for (final child in children) ...[
                        _ChildDay(child: child, tint: tint),
                        const SizedBox(height: kCardGap),
                      ],
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

class _ChildDay extends StatelessWidget {
  const _ChildDay({required this.child, required this.tint});

  final FamilyChildDay child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final status = child.closed
        ? t('familyDay.closed')
        : child.noBus
            ? t('familyDay.noBus')
            : null;
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitials(label: child.name, tint: tint, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.text)),
                    if ((child.school ?? '').isNotEmpty)
                      Text(child.school!, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (status != null) ...[
            Pill(status, color: child.closed ? AppTheme.rose : AppTheme.amber),
            if ((child.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(child.note!, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
            ],
          ] else ...[
            _Moment(label: t('familyDay.pickup'), moment: child.pickup, icon: Icons.north_east_rounded, tint: tint),
            const SizedBox(height: 8),
            _Moment(label: t('familyDay.dropoff'), moment: child.dropoff, icon: Icons.south_west_rounded, tint: tint),
          ],
        ],
      ),
    );
  }
}

class _Moment extends StatelessWidget {
  const _Moment({required this.label, required this.moment, required this.icon, required this.tint});

  final String label;
  final FamilyMoment? moment;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final at = moment?.at;
    return Row(
      children: [
        Icon(icon, size: 17, color: tint),
        const SizedBox(width: 8),
        SizedBox(
          width: 86,
          child: Text(label, style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
        ),
        Text(
          at == null ? '—' : ltrIsolated(hhmm(at)),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.text),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            moment?.place ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }
}
