import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/student_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';
import 'hand_in_screen.dart';

class StudentHomeworkScreen extends StatefulWidget {
  const StudentHomeworkScreen({super.key});

  @override
  State<StudentHomeworkScreen> createState() => _StudentHomeworkScreenState();
}

class _StudentHomeworkScreenState extends State<StudentHomeworkScreen> {
  bool _includeDone = false;

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('student.homework')),
            Padding(
              padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 10),
              child: Row(
                children: [
                  _Toggle(
                    label: t('student.stillToDo'),
                    on: !_includeDone,
                    tint: tint,
                    onTap: () => setState(() => _includeDone = false),
                  ),
                  const SizedBox(width: 8),
                  _Toggle(
                    label: t('student.everything'),
                    on: _includeDone,
                    tint: tint,
                    onTap: () => setState(() => _includeDone = true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Loader<Paged<Homework>>(
                tint: tint,
                watch: _includeDone,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: () => StudentApi.instance.homework(
                  includeDone: _includeDone,
                  pageSize: 50,
                ),
                isEmpty: (page) => page.rows.isEmpty,
                empty: t('student.noHomework'),
                builder: (context, page) => Column(
                  children: [
                    for (final work in page.rows) ...[
                      _HomeworkCard(work: work),
                      const SizedBox(height: kCardGap),
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

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.on,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final bool on;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: on ? tint : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? tint : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: on ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({required this.work});

  final Homework work;

  @override
  Widget build(BuildContext context) {
    final colour = parseHex(work.subjectColorHex, AppTheme.amber);
    final done = work.submitted != null;

    return Card16(
      padding: const EdgeInsets.all(14),
      onTap: () => showAppSheet<void>(context, builder: (_) => _HomeworkSheet(work: work)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: subjectIcon(work.subject), color: colour),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        work.subject,
                        if ((work.teacherName ?? '').isNotEmpty) work.teacherName!,
                      ].join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(
                done ? t('student.handedIn') : dueWord(work.daysLeft),
                color: done
                    ? AppTheme.green
                    : work.daysLeft < 1
                        ? AppTheme.rose
                        : colour,
              ),
              if (work.dueDate != null) Pill(shortDate(work.dueDate), color: AppTheme.textMuted),
              if (work.estimatedMinutes != null)
                Pill(tn('student.minutes', work.estimatedMinutes!), color: AppTheme.blue),
              if (work.score != null)
                Pill(
                  '${work.score!.round()} / ${(work.maxScore ?? 0).round()}',
                  color: AppTheme.violet,
                ),
              if (work.handInOpen && !done) Pill(t('student.handIn'), color: AppTheme.blue),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeworkSheet extends StatelessWidget {
  const _HomeworkSheet({required this.work});

  final Homework work;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: withBottomInset(context, const EdgeInsets.fromLTRB(20, 12, 20, 24)),
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
            const SizedBox(height: 18),
            Text(
              work.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.3,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                work.subject,
                if ((work.teacherName ?? '').isNotEmpty) work.teacherName!,
                if (work.dueDate != null) longDate(work.dueDate),
              ].join('  •  '),
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.45),
            ),
            if ((work.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                work.description!,
                style: TextStyle(fontSize: 13.5, height: 1.6, color: AppTheme.text),
              ),
            ],
            if (work.score != null) ...[
              const SizedBox(height: 16),
              TileRow(
                icon: Icons.workspace_premium_outlined,
                color: AppTheme.violet,
                title: t('student.yourMark'),
                trailing: '${work.score!.round()} / ${(work.maxScore ?? 0).round()}',
                trailingColor: AppTheme.violet,
                last: true,
              ),
            ],
            if ((work.feedback ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                t('student.teacherFeedback'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTheme.textFaint,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                work.feedback!,
                style: TextStyle(fontSize: 13, height: 1.6, color: AppTheme.text),
              ),
            ],
            if (work.handInOpen) ...[
              const SizedBox(height: 20),
              BigButton(
                label: t('student.handIn'),
                color: parseHex(work.subjectColorHex, AppTheme.amber),
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => StudentHandInScreen(homeworkId: work.id),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
