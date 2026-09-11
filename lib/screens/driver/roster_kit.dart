import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/format.dart';

enum RosterFilter { all, toPickUp, aboard, done }

({String text, Color tone}) riderStatus(
  RiderOnStop r, {
  required String leg,
  required bool schoolReached,
}) {
  final onBus = r.boardedAt != null && r.alightedAt == null;
  final off = r.alightedAt != null;

  if (off) {
    final word = leg == 'OUT'
        ? (schoolReached ? t('driver.atSchool') : t('driver.setDownEarly'))
        : t('driver.handedOver');
    return (
      text: '$word ${hhmm(r.alightedAt)}',
      tone: leg == 'OUT' && !schoolReached ? AppTheme.amber : AppTheme.green,
    );
  }
  if (onBus) {
    return (
      text: tn('driver.onBoardSince', hhmm(r.boardedAt)),
      tone: AppTheme.blue,
    );
  }
  if (r.notTravelling) {
    return (text: t('driver.notRiding'), tone: AppTheme.rose);
  }
  return (text: t('driver.waitingAtStop'), tone: AppTheme.textMuted);
}

Color riderTone(RiderOnStop r) {
  if (r.alightedAt != null) return AppTheme.green;
  if (r.boardedAt != null) return AppTheme.blue;
  if (r.notTravelling) return AppTheme.rose;
  return AppTheme.textMuted;
}

Color riderWash(RiderOnStop r) {
  if (r.alightedAt != null) return AppTheme.greenSoft;
  if (r.boardedAt != null) return AppTheme.blueSoft;
  if (r.notTravelling) return AppTheme.roseSoft;
  return AppTheme.neutralSoft;
}

class SeatChip extends StatelessWidget {
  const SeatChip({super.key, required this.rider, this.size = 38});

  final RiderOnStop rider;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: riderWash(rider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        rider.seatNumber ?? '—',
        maxLines: 1,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: riderTone(rider),
        ),
      ),
    );
  }
}

class RosterChip extends StatelessWidget {
  const RosterChip({
    super.key,
    required this.label,
    required this.count,
    required this.on,
    required this.colour,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool on;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: on ? colour : AppTheme.neutralSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class RosterFilters extends StatelessWidget {
  const RosterFilters({
    super.key,
    required this.riders,
    required this.value,
    required this.onChanged,
  });

  final List<RiderOnStop> riders;
  final RosterFilter value;
  final ValueChanged<RosterFilter> onChanged;

  static List<RiderOnStop> apply(List<RiderOnStop> riders, RosterFilter f) =>
      switch (f) {
        RosterFilter.all => riders,
        RosterFilter.toPickUp => riders.where((r) => !r.accountedFor).toList(),
        RosterFilter.aboard => riders
            .where((r) => r.boardedAt != null && r.alightedAt == null)
            .toList(),
        RosterFilter.done => riders.where((r) => r.alightedAt != null).toList(),
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          RosterChip(
            label: t('driver.filterAll'),
            count: riders.length,
            on: value == RosterFilter.all,
            colour: Role.driver.tint,
            onTap: () => onChanged(RosterFilter.all),
          ),
          RosterChip(
            label: t('driver.toPickUp'),
            count: apply(riders, RosterFilter.toPickUp).length,
            on: value == RosterFilter.toPickUp,
            colour: AppTheme.amber,
            onTap: () => onChanged(RosterFilter.toPickUp),
          ),
          RosterChip(
            label: t('driver.onBoard'),
            count: apply(riders, RosterFilter.aboard).length,
            on: value == RosterFilter.aboard,
            colour: AppTheme.blue,
            onTap: () => onChanged(RosterFilter.aboard),
          ),
          RosterChip(
            label: t('driver.dropped'),
            count: apply(riders, RosterFilter.done).length,
            on: value == RosterFilter.done,
            colour: AppTheme.green,
            onTap: () => onChanged(RosterFilter.done),
          ),
        ],
      ),
    );
  }
}

class WordButton extends StatelessWidget {
  const WordButton({
    super.key,
    required this.label,
    required this.colour,
    required this.onTap,
    this.icon,
  });

  final String label;

  final IconData? icon;
  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dead = onTap == null;
    final tone = dead ? AppTheme.textFaint : colour;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: dead ? 0.07 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: tone),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
