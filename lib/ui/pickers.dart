import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'format.dart';
import 'kit.dart';
import 'sheets.dart';

/// Choosing a date, and choosing from a list.
///
/// Both were Flutter's defaults with a colour scheme applied. That is not the
/// same as belonging: Material's date picker has its own corner radius, its own
/// grid metrics, its own header, and a dropdown opens a floating menu that
/// looks nothing like the rest of these screens. On a form a parent uses twice
/// a term, the moment it opens is the moment the app stops feeling like one
/// thing.
///
/// These are sheets, because everything else that asks a question in this app
/// is a sheet, and they are built from the same Card16 / Pill / BigButton
/// vocabulary as the screens behind them.

/// A month grid, as a sheet.
///
/// Returns the chosen day, or null if dismissed.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  required Color tint,
  String? title,
}) {
  return showAppSheet<DateTime>(
    context,
    builder: (_) => _DateSheet(
      initial: initial,
      first: first,
      last: last,
      tint: tint,
      title: title ?? t('pick.date'),
    ),
  );
}

/// One choice from a short list, as a sheet.
///
/// A sheet rather than a menu because a menu that opens over the field hides
/// the thing being answered, and because on a phone a list of classes is
/// easier to hit at full width than in a 200px popup.
Future<T?> pickOne<T>(
  BuildContext context, {
  required List<PickOption<T>> options,
  required Color tint,
  T? selected,
  String? title,
}) {
  return showAppSheet<T>(
    context,
    builder: (_) => _OptionSheet<T>(
      options: options,
      selected: selected,
      tint: tint,
      title: title ?? t('pick.choose'),
    ),
  );
}

class PickOption<T> {
  const PickOption({required this.value, required this.label, this.subtitle, this.icon});

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/* ---------------------------------------------------------------------------
 * The sheets
 * ------------------------------------------------------------------------- */

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppTheme.text,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 20, color: AppTheme.textFaint),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(child: child),
        ],
      ),
    );
  }
}

class _DateSheet extends StatefulWidget {
  const _DateSheet({
    required this.initial,
    required this.first,
    required this.last,
    required this.tint,
    required this.title,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final Color tint;
  final String title;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _month;
  late DateTime _chosen;

  @override
  void initState() {
    super.initState();
    _chosen = _dayOf(widget.initial);
    _month = DateTime(_chosen.year, _chosen.month);
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _allowed(DateTime day) =>
      !day.isBefore(_dayOf(widget.first)) && !day.isAfter(_dayOf(widget.last));

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;

    // The week starts on Saturday in the Region, not Monday and not Sunday.
    // Dart gives Monday = 1 … Sunday = 7, so Saturday (6) becomes column 0.
    final lead = (firstOfMonth.weekday + 1) % 7;

    final canBack = !DateTime(_month.year, _month.month, 1)
        .isBefore(DateTime(widget.first.year, widget.first.month, 1).add(const Duration(days: 1)));
    final canForward = DateTime(_month.year, _month.month + 1, 1)
        .isBefore(DateTime(widget.last.year, widget.last.month + 1, 1).add(const Duration(days: 1)));

    return _SheetFrame(
      title: widget.title,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Arrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: canBack ? () => _shift(-1) : null,
                  ),
                  Expanded(
                    child: Text(
                      monthYear(_month),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  _Arrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: canForward ? () => _shift(1) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final label in weekdayInitials())
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textFaint,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.05,
                ),
                itemCount: lead + daysInMonth,
                itemBuilder: (context, i) {
                  if (i < lead) return const SizedBox.shrink();
                  final day = DateTime(_month.year, _month.month, i - lead + 1);
                  final chosen = day == _chosen;
                  final today = day == _dayOf(DateTime.now());
                  final allowed = _allowed(day);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: allowed ? () => setState(() => _chosen = day) : null,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: chosen ? widget.tint : Colors.transparent,
                          shape: BoxShape.circle,
                          // Today is outlined, the chosen day is filled. Two
                          // different facts, so they must not look alike.
                          border: today && !chosen
                              ? Border.all(color: widget.tint, width: 1.4)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: chosen || today ? FontWeight.w800 : FontWeight.w600,
                            color: !allowed
                                ? AppTheme.textFaint.withValues(alpha: 0.45)
                                : chosen
                                    ? Colors.white
                                    : AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              BigButton(
                label: '${t('pick.choose')} · ${longDate(_chosen)}',
                color: widget.tint,
                height: 50,
                onPressed: () => Navigator.of(context).pop(_chosen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(
          icon,
          size: 19,
          color: onTap == null ? AppTheme.textFaint.withValues(alpha: 0.4) : AppTheme.textMuted,
        ),
      ),
    );
  }
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.options,
    required this.selected,
    required this.tint,
    required this.title,
  });

  final List<PickOption<T>> options;
  final T? selected;
  final Color tint;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: title,
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final o = options[i];
          final on = o.value == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(o.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: on ? tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10) : AppTheme.canvas,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: on ? tint : AppTheme.border,
                  width: on ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (o.icon != null) ...[
                    Icon(o.icon, size: 18, color: on ? tint : AppTheme.textMuted),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                            color: AppTheme.text,
                          ),
                        ),
                        if (o.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            o.subtitle!,
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (on) Icon(Icons.check_circle_rounded, size: 20, color: tint),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A form row that opens one of the sheets above.
///
/// Looks like the app's other fields rather than like a Material dropdown, and
/// says what is chosen rather than showing a caret over an empty box.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.expand_more_rounded,
    this.placeholder,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData icon;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // An empty label is no label, not a blank line. Callers that already
        // draw their own heading pass '' — and the invisible Text plus its gap
        // made those fields taller than the ones beside them, which is what
        // knocked "Out of" off the same line as "Date".
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    empty ? (placeholder ?? '') : value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: empty ? AppTheme.textFaint : AppTheme.text,
                    ),
                  ),
                ),
                Icon(icon, size: 20, color: AppTheme.textFaint),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
