import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

class ChildDropoff {
  ChildDropoff({
    required this.child,
    required this.usualStop,
    required this.options,
    required this.note,
  });

  final Child child;
  final String? usualStop;
  final List<DropoffOption> options;
  final String note;
}

class DropoffScreen extends StatefulWidget {
  const DropoffScreen({super.key});

  @override
  State<DropoffScreen> createState() => _DropoffScreenState();
}

class _DropoffScreenState extends State<DropoffScreen> {
  final _loader = GlobalKey<LoaderState<List<ChildDropoff>>>();

  Future<List<ChildDropoff>> _load() async {
    final children = await ParentApi.instance.children();
    final out = <ChildDropoff>[];
    for (final child in children) {
      try {
        final options = await ParentApi.instance.dropoffOptions(
          child.studentId,
          tenantId: child.tenantId,
        );
        out.add(ChildDropoff(
          child: child,
          usualStop: options.usualStop,
          options: options.options,
          note: options.note,
        ));
      } on ApiException {
        out.add(ChildDropoff(child: child, usualStop: null, options: const [], note: ''));
      }
    }
    return out;
  }

  Future<void> _request(Child child, DropoffOption option) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(stopName: option.stopName),
    );
    if (reason == null || !mounted) return;

    try {
      await ParentApi.instance.requestDropoffChange(
        studentId: child.studentId,
        alternateStopId: option.id,
        reason: reason.trim().isEmpty ? null : reason.trim(),
        tenantId: child.tenantId,
      );
      if (!mounted) return;
      showNote(context, tn('dropoff.sent', child.name.split(' ').first));
      _loader.currentState?.reload(quiet: true);
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
            ScreenHeader(title: t('dropoff.title'), subtitle: t('dropoff.subtitle')),
            Expanded(
              child: Loader<List<ChildDropoff>>(
                key: _loader,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: _load,
                empty: t('common.noChildren'),
                isEmpty: (rows) => rows.isEmpty,
                builder: (context, rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NoticeBanner(
                      icon: Icons.info_outline_rounded,
                      color: tint,
                      title: t('dropoff.officeApprovesTitle'),
                      body: t('dropoff.officeApproves'),
                    ),
                    const SizedBox(height: kCardGap),
                    for (final row in rows) ...[
                      _ChildCard(row: row, onPick: (o) => _request(row.child, o)),
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

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.row, required this.onPick});

  final ChildDropoff row;
  final ValueChanged<DropoffOption> onPick;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitials(label: row.child.name, tint: tint, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    Text(
                      (row.usualStop ?? '').isEmpty
                          ? t('dropoff.noStop')
                          : tn('dropoff.usual', row.usualStop!),
                      maxLines: 2,
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (row.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              row.note,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: AppTheme.textFaint),
            ),
          ],
          const SizedBox(height: 10),
          if (row.options.isEmpty)
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.neutralSoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                t('dropoff.noAlternates'),
                style: TextStyle(fontSize: 12, height: 1.55, color: AppTheme.textMuted),
              ),
            )
          else ...[
            Text(
              t('dropoff.pick'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 6),
            for (final option in row.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined, size: 17, color: tint),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label.isEmpty ? option.stopName : option.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.text,
                                ),
                              ),
                              if (option.stopName.isNotEmpty)
                                Text(
                                  [option.stopName, if ((option.landmark ?? '').isNotEmpty) option.landmark!]
                                      .join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textFaint),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.stopName});

  final String stopName;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tn('dropoff.requestTitle', widget.stopName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('dropoff.requestBody'), style: const TextStyle(height: 1.55)),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t('dropoff.reasonHint'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(t('dropoff.send')),
        ),
      ],
    );
  }
}
