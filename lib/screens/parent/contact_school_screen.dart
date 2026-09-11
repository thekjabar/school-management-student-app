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

class ContactSchoolScreen extends StatefulWidget {
  const ContactSchoolScreen({super.key, required this.child});

  final Child child;

  @override
  State<ContactSchoolScreen> createState() => _ContactSchoolScreenState();
}

class _ContactSchoolScreenState extends State<ContactSchoolScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<ConcernStatus>>>();

  static const _topics = <(String, IconData, bool)>[
    ('CHILD_NOT_HOME', Icons.report_problem_rounded, true),
    ('BUS_LATE', Icons.schedule_rounded, true),
    ('PICKUP_ARRANGEMENT', Icons.directions_car_rounded, false),
    ('SOMETHING_ELSE', Icons.help_outline_rounded, false),
  ];

  Future<void> _raise(String topic, bool urgent) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _MessageDialog(topic: topic, urgent: urgent),
    );
    if (message == null) return;
    try {
      final res = await ParentApi.instance.raiseConcern(
        studentId: widget.child.studentId,
        urgency: urgent ? 'URGENT' : 'QUESTION',
        topic: topic,
        message: message,
      );
      if (!mounted) return;
      final times = (res['timesRaised'] as num?)?.toInt() ?? 1;
      showNote(
        context,
        times > 1 ? tn('contact.sentAgain', times) : t('contact.sent'),
      );
      _loaderKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
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
            ScreenHeader(title: t('contact.title')),
            Expanded(
              child: Loader<List<ConcernStatus>>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                load: () => ParentApi.instance.concerns(studentId: widget.child.studentId),
                builder: (context, rows) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tn('contact.lead', widget.child.name.split(' ').first),
                        style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 14),
                      for (final tp in _topics) ...[
                        _TopicCard(
                          topic: tp.$1,
                          icon: tp.$2,
                          urgent: tp.$3,
                          onTap: () => _raise(tp.$1, tp.$3),
                        ),
                        const SizedBox(height: kCardGap),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.phone_in_talk_rounded, size: 16, color: AppTheme.textFaint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t('contact.answeredByPhone'),
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rows.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        Text(
                          t('contact.yours'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 9),
                        for (final r in rows) ...[
                          _ConcernCard(row: r),
                          const SizedBox(height: kCardGap),
                        ],
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

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.icon,
    required this.urgent,
    required this.onTap,
  });

  final String topic;
  final IconData icon;
  final bool urgent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = urgent ? AppTheme.rose : Role.parent.tint;

    return Card16(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 21, color: colour),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('contact.topic.$topic'),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('contact.topicLine.$topic'),
                  style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textFaint),
        ],
      ),
    );
  }
}

class _ConcernCard extends StatelessWidget {
  const _ConcernCard({required this.row});

  final ConcernStatus row;

  @override
  Widget build(BuildContext context) {
    final (Color colour, String label) = switch (row.state) {
      'SEEN' => (AppTheme.blue, t('contact.state.SEEN')),
      'CLOSED' => (AppTheme.green, t('contact.state.CLOSED')),
      _ => (AppTheme.amber, t('contact.state.SENT')),
    };

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppTheme.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pill(label, color: colour),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            row.timesRaised > 1
                ? '${longDate(row.raisedAt)}  •  ${tn('contact.timesRaised', row.timesRaised)}'
                : longDate(row.raisedAt),
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _MessageDialog extends StatefulWidget {
  const _MessageDialog({required this.topic, required this.urgent});

  final String topic;
  final bool urgent;

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colour = widget.urgent ? AppTheme.rose : Role.parent.tint;

    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('contact.topic.${widget.topic}'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t('contact.messageHint'),
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              autofocus: true,
              maxLines: 4,
              maxLength: 600,
              style: TextStyle(fontSize: 14, color: AppTheme.text),
              decoration: InputDecoration(
                hintText: t('contact.messagePlaceholder'),
                counterText: '',
                filled: true,
                fillColor: AppTheme.canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                  child: Text(t('common.cancel')),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _busy = true);
                          Navigator.of(context).pop(_text.text);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: colour,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(t('contact.send')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
