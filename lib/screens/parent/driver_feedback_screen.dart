import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// What a family says about the person driving their child.
///
/// This conversation happens today by telephone to the transport contractor,
/// and the school hears about it late or never. Praise never gets recorded at
/// all, which matters: a record that only ever fills with complaints is one no
/// operator will trust and no driver will accept being judged by. So praise is
/// the first of the two choices, not an afterthought.
///
/// The screen says plainly what this is not. Anything about a child being hurt
/// or frightened needs the school on the telephone now, not a form that reaches
/// an inbox somebody opens on Sunday.
class DriverFeedbackScreen extends StatefulWidget {
  const DriverFeedbackScreen({super.key, required this.child});

  final Child child;

  @override
  State<DriverFeedbackScreen> createState() => _DriverFeedbackScreenState();
}

class _DriverFeedbackScreenState extends State<DriverFeedbackScreen> {
  final _loader = GlobalKey<LoaderState<List<CrewFeedbackItem>>>();

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('crew.title'), onBell: () {}),
            Expanded(
              child: Loader<List<CrewFeedbackItem>>(
                key: _loader,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: () => ParentApi.instance.crewFeedback(widget.child.studentId),
                builder: (context, rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Intro(tint: tint, onTap: _compose),
                    const SizedBox(height: kCardGap),

                    // The line that keeps this form out of the way of a real
                    // safeguarding concern.
                    NoticeBanner(
                      icon: Icons.phone_in_talk_outlined,
                      title: t('crew.seriousTitle'),
                      body: t('crew.seriousBody'),
                      color: AppTheme.amber,
                    ),

                    if (rows.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SectionRow(title: t('crew.yours')),
                      const SizedBox(height: 4),
                      for (final r in rows) ...[
                        _FeedbackRow(item: r),
                        const SizedBox(height: kCardGap),
                      ],
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

  Future<void> _compose() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(child: widget.child),
    );
    if (sent == true && mounted) {
      _loader.currentState?.reload();
      showNote(context, t('crew.sent'));
    }
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.tint, required this.onTap});

  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('crew.introTitle'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('crew.introBody'),
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          BigButton(
            label: t('crew.write'),
            color: tint,
            height: 50,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.item});

  final CrewFeedbackItem item;

  @override
  Widget build(BuildContext context) {
    final colour = item.isPraise ? AppTheme.green : AppTheme.amber;

    return Card16(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: AppTheme.dark ? 0.22 : 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  item.isPraise ? Icons.thumb_up_outlined : Icons.report_problem_outlined,
                  size: 17,
                  color: colour,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.crewName ?? t('crew.unnamed'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _when(item),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChipFor(item: item),
            ],
          ),
          if (item.topics.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final topic in item.topics)
                  StatusChip(t('crew.topic.$topic'), color: colour),
              ],
            ),
          ],
          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.comment!,
              style: TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.text),
            ),
          ],
        ],
      ),
    );
  }

  static String _when(CrewFeedbackItem item) {
    final day = shortDate(item.occurredOn);
    if (item.direction == 'UNSPECIFIED') return day;
    return '$day · ${t('crew.leg.${item.direction}')}';
  }
}

/// Where the office has got to, and nothing about what it decided.
class _StatusChipFor extends StatelessWidget {
  const _StatusChipFor({required this.item});

  final CrewFeedbackItem item;

  @override
  Widget build(BuildContext context) {
    final colour = switch (item.status) {
      'NEW' => AppTheme.blue,
      'UNDER_REVIEW' => AppTheme.violet,
      'ESCALATED' => AppTheme.rose,
      _ => AppTheme.green,
    };
    return StatusChip(t('crew.status.${item.status}'), color: colour);
  }
}

/* ---------------------------------------------------------------------------
 * Writing one
 * ------------------------------------------------------------------------- */

const _topics = [
  'DRIVING',
  'PUNCTUALITY',
  'MANNER',
  'SAFETY',
  'VEHICLE_CONDITION',
  'HANDOVER',
  'COMMUNICATION',
  'OTHER',
];

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.child});

  final Child child;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _comment = TextEditingController();

  String _sentiment = 'PRAISE';
  String _direction = 'UNSPECIFIED';
  final Set<String> _chosen = {};
  DateTime _day = DateTime.now();
  String? _crewPersonId;

  List<RecentCrew> _crew = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Best effort. A parent must still be able to send this when the lookup
    // fails — the server resolves the driver from the journey anyway.
    ParentApi.instance
        .recentCrew(widget.child.studentId)
        .then((c) => mounted ? setState(() => _crew = c) : null)
        .catchError((_) => null);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t('crew.write'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 14),

              // Praise first. A driver is far more likely to be doing the job
              // well than badly, and a form that opens on "complaint" collects
              // only complaints.
              Row(
                children: [
                  Expanded(
                    child: _Choice(
                      icon: Icons.thumb_up_outlined,
                      label: t('crew.praise'),
                      colour: AppTheme.green,
                      selected: _sentiment == 'PRAISE',
                      onTap: () => setState(() => _sentiment = 'PRAISE'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _Choice(
                      icon: Icons.report_problem_outlined,
                      label: t('crew.concern'),
                      colour: AppTheme.amber,
                      selected: _sentiment == 'CONCERN',
                      onTap: () => setState(() => _sentiment = 'CONCERN'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _Label(t('crew.whichDay')),
              const SizedBox(height: 7),
              _Tappable(
                icon: Icons.event_outlined,
                text: longDate(_day),
                onTap: _pickDay,
              ),
              const SizedBox(height: 12),

              _Label(t('crew.whichRun')),
              const SizedBox(height: 7),
              Row(
                children: [
                  for (final leg in const ['MORNING', 'AFTERNOON', 'UNSPECIFIED'])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 7),
                      child: _Pill(
                        label: t('crew.leg.$leg'),
                        selected: _direction == leg,
                        tint: tint,
                        onTap: () => setState(() => _direction = leg),
                      ),
                    ),
                ],
              ),

              if (_crew.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Label(t('crew.whichPerson')),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Pill(
                      label: t('crew.dontKnow'),
                      selected: _crewPersonId == null,
                      tint: tint,
                      onTap: () => setState(() => _crewPersonId = null),
                    ),
                    for (final c in _crew)
                      _Pill(
                        label: c.name,
                        selected: _crewPersonId == c.personId,
                        tint: tint,
                        onTap: () => setState(() => _crewPersonId = c.personId),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 14),
              _Label(t('crew.whatAbout')),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final topic in _topics)
                    _Pill(
                      label: t('crew.topic.$topic'),
                      selected: _chosen.contains(topic),
                      tint: tint,
                      onTap: () => setState(() {
                        _chosen.contains(topic) ? _chosen.remove(topic) : _chosen.add(topic);
                      }),
                    ),
                ],
              ),

              const SizedBox(height: 14),
              _Label(
                _sentiment == 'CONCERN' ? t('crew.whatHappened') : t('crew.anythingElse'),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _comment,
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: t('crew.commentHint'),
                    hintStyle: TextStyle(fontSize: 14, color: AppTheme.textFaint),
                  ),
                  style: TextStyle(fontSize: 14.5, height: 1.4, color: AppTheme.text),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.rose,
                  ),
                ),
              ],

              const SizedBox(height: 14),
              BigButton(
                label: t('crew.send'),
                color: tint,
                height: 52,
                busy: _busy,
                onPressed: _canSend ? _send : null,
              ),
              const SizedBox(height: 8),
              Text(
                t('crew.privacyNote'),
                style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A concern with no detail cannot be looked into, so the button waits for
  /// one rather than letting the server refuse after the fact.
  bool get _canSend =>
      !_busy && (_sentiment == 'PRAISE' || _comment.text.trim().length >= 2);

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      // Sixty days, the window the server accepts — beyond it the telemetry and
      // manifest the office would check against have aged out.
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentApi.instance.sendCrewFeedback(
        studentId: widget.child.studentId,
        sentiment: _sentiment,
        occurredOn: _day,
        topics: _chosen.toList(),
        comment: _comment.text,
        direction: _direction,
        crewPersonId: _crewPersonId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: AppTheme.textMuted,
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.label,
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.10)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? colour : AppTheme.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 21, color: selected ? colour : AppTheme.textMuted),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: selected ? colour : AppTheme.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.11)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tint : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: selected ? tint : AppTheme.text,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.icon, required this.text, required this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppTheme.text,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 20, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
