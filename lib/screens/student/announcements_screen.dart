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

class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.student.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('student.announcements')),
            Expanded(
              child: Loader<Paged<StudentNotice>>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 24),
                load: () => StudentApi.instance.announcements(pageSize: 50),
                isEmpty: (page) => page.rows.isEmpty,
                empty: t('student.noNews'),
                builder: (context, page) => Column(
                  children: [
                    for (final notice in page.rows) ...[
                      _NoticeCard(notice: notice),
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final StudentNotice notice;

  @override
  Widget build(BuildContext context) {
    final urgent = notice.priority == 'URGENT' || notice.priority == 'HIGH';
    final colour = urgent ? AppTheme.rose : AppTheme.blue;

    return Card16(
      padding: const EdgeInsets.all(14),
      onTap: () => showAppSheet<void>(context, builder: (_) => _NoticeSheet(notice: notice)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(
                icon: notice.pinned ? Icons.push_pin_rounded : Icons.campaign_rounded,
                color: colour,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notice.title,
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
                        if (notice.authorName.isNotEmpty) notice.authorName,
                        shortDate(notice.sentAt),
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
          const SizedBox(height: 10),
          Text(
            notice.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, height: 1.55, color: AppTheme.textMuted),
          ),
          if (notice.category != null || notice.attachmentCount > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (notice.category != null) Pill(humanise(notice.category), color: colour),
                if (notice.attachmentCount > 0)
                  Pill(tn('student.attachments', notice.attachmentCount), color: AppTheme.violet),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeSheet extends StatelessWidget {
  const _NoticeSheet({required this.notice});

  final StudentNotice notice;

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
              notice.title,
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
                if (notice.authorName.isNotEmpty) notice.authorName,
                longDate(notice.sentAt),
              ].join('  •  '),
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              notice.body,
              style: TextStyle(fontSize: 13.5, height: 1.65, color: AppTheme.text),
            ),
          ],
        ),
      ),
    );
  }
}
