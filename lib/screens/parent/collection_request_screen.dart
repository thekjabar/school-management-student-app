import 'package:flutter/material.dart';

import '../../api/biometrics.dart';
import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

class CollectionRequestScreen extends StatefulWidget {
  const CollectionRequestScreen({super.key, required this.child, this.ridesTheBus = true});

  final Child child;

  final bool ridesTheBus;

  @override
  State<CollectionRequestScreen> createState() => _CollectionRequestScreenState();
}

class _CollectionRequestScreenState extends State<CollectionRequestScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<ConcernStatus>>>();

  String get _firstName => widget.child.name.split(' ').first;

  Future<void> _open() async {
    final sent = await showAppSheet<_Sent>(
      context,
      builder: (_) => _RequestSheet(child: widget.child, ridesTheBus: widget.ridesTheBus),
    );
    if (sent == null || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
      builder: (_) => _Receipt(
        title: t('ota.sentTitle'),
        body: sent.replacedAnother
            ? '${tn('ota.sentBody', _firstName)}\n\n${tn('ota.sentReplaced', _firstName)}'
            : tn('ota.sentBody', _firstName),
      ),
    );
    if (!mounted) return;
    _loaderKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        backgroundColor: tint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.how_to_reg_rounded),
        label: Text(t('ota.new')),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('ota.title')),
            ChildCard(
              name: widget.child.name,
              line: '${widget.child.className}  •  ${widget.child.code}',
              tint: tint,
            ),
            Expanded(
              child: Loader<List<ConcernStatus>>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 96),
                load: () => ParentApi.instance.concerns(
                      studentId: widget.child.studentId,
                      topic: 'PICKUP_ARRANGEMENT',
                    ),
                builder: (context, rows) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tn('ota.lead', _firstName),
                        style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),

                      NoticeBanner(
                        icon: Icons.gpp_maybe_rounded,
                        color: AppTheme.amber,
                        title: t('ota.notPermissionTitle'),
                        body: tn('ota.notPermissionBody', _firstName),
                      ),
                      const SizedBox(height: kCardGap),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.phone_in_talk_rounded, size: 16, color: AppTheme.textFaint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t('ota.answeredByPhone'),
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.repeat_rounded, size: 16, color: AppTheme.textFaint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tn('ota.standing', _firstName),
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      Text(
                        tn('ota.yours', _firstName),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (rows.isEmpty)
                        Text(
                          tn('ota.none', _firstName),
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        )
                      else
                        for (final r in rows) ...[
                          _RequestCard(row: r),
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

class _Sent {
  const _Sent({required this.replacedAnother});

  final bool replacedAnother;
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.row});

  final ConcernStatus row;

  @override
  Widget build(BuildContext context) {
    final (Color colour, String label, String meaning) = switch (row.state) {
      'SEEN' => (AppTheme.blue, t('ota.state.SEEN'), t('ota.stateMeaning.SEEN')),
      'CLOSED' => (AppTheme.textMuted, t('ota.state.CLOSED'), t('ota.stateMeaning.CLOSED')),
      _ => (AppTheme.amber, t('ota.state.SENT'), t('ota.stateMeaning.SENT')),
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
                ? '${longDate(row.raisedAt)}  •  ${tn('ota.timesSent', row.timesRaised)}'
                : longDate(row.raisedAt),
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            meaning,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: colour),
          ),
        ],
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_top_rounded, size: 30, color: AppTheme.amber),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  t('common.close'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.child, required this.ridesTheBus});

  final Child child;
  final bool ridesTheBus;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  static const _relations = <(String, IconData)>[
    ('BROTHER', Icons.man_rounded),
    ('SISTER', Icons.woman_rounded),
    ('UNCLE', Icons.person_rounded),
    ('AUNT', Icons.person_2_rounded),
    ('GRANDPARENT', Icons.elderly_rounded),
    ('NEIGHBOUR', Icons.home_rounded),
    ('OTHER', Icons.more_horiz_rounded),
  ];

  static const _maxMessage = 600;

  static const _maxDaysAhead = 14;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _note = TextEditingController();

  String _relation = 'BROTHER';
  String _leg = 'RETURN';
  DateTime _day = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _idNumber.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await pickDate(
      context,
      initial: _day,
      first: today,
      last: today.add(const Duration(days: _maxDaysAhead)),
      tint: Role.parent.tint,
    );
    if (picked != null) setState(() => _day = picked);
  }

  String _message() {
    final lines = <String>[
      t('ota.msg.heading'),
      '${t('ota.msg.who')} ${_name.text.trim()}',
      '${t('ota.msg.relation')} ${t('ota.rel.$_relation')}',
      if (_phone.text.trim().isNotEmpty) '${t('ota.msg.phone')} ${_phone.text.trim()}',
      if (_idNumber.text.trim().isNotEmpty) '${t('ota.msg.id')} ${_idNumber.text.trim()}',
      '${t('ota.msg.day')} ${longDate(_day)}',
      if (widget.ridesTheBus)
        '${t('ota.msg.run')} ${t('ota.leg.$_leg')}'
      else
        t('ota.msg.atGate'),
    ];
    var out = lines.join('\n');

    final note = _note.text.trim();
    if (note.isNotEmpty) {
      final label = t('ota.msg.note');
      final room = _maxMessage - out.length - label.length - 2;
      if (room > 12) {
        final body = note.length > room ? note.substring(0, room) : note;
        out = '$out\n$label $body';
      }
    }
    return out.length > _maxMessage ? out.substring(0, _maxMessage) : out;
  }

  Future<void> _send() async {
    final who = _name.text.trim();
    if (who.length < 2) {
      setState(() => _error = t('ota.whoRequired'));
      return;
    }

    final sure = await confirmDialog(
      context,
      icon: Icons.gpp_maybe_rounded,
      title: t('ota.confirmTitle'),
      body: tv('ota.confirmBody', {'who': who, 'n': widget.child.name.split(' ').first}),
      confirmLabel: t('ota.confirmSend'),
      confirmIcon: Icons.send_rounded,
      tone: AppTheme.amber,
    );
    if (!sure || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await Biometrics.confirm(reason: t('ota.confirmWithBiometrics'));
      if (!ok) {
        if (mounted) setState(() => _error = t('ota.notConfirmed'));
        return;
      }

      final res = await ParentApi.instance.raiseConcern(
        studentId: widget.child.studentId,
        urgency: _isToday ? 'URGENT' : 'QUESTION',
        topic: 'PICKUP_ARRANGEMENT',
        message: _message(),
      );
      if (!mounted) return;
      final times = (res['timesRaised'] as num?)?.toInt() ?? 1;
      Navigator.of(context).pop(_Sent(replacedAnother: times > 1));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.status == 409
            ? tn('ota.notSent', widget.child.name.split(' ').first)
            : e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('ota.newTitle'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tn('ota.newLine', widget.child.name.split(' ').first),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              _Label(t('ota.who')),
              const SizedBox(height: 8),
              _Field(
                controller: _name,
                hint: t('ota.whoHint'),
                maxLength: 80,
                autofocus: true,
                capitals: TextCapitalization.words,
              ),

              const SizedBox(height: 16),
              _Label(tn('ota.relation', widget.child.name.split(' ').first)),
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 8.0;
                  final w = (box.maxWidth - gap * 2) / 3;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final r in _relations)
                        SizedBox(
                          width: w,
                          child: _Tile(
                            label: t('ota.rel.${r.$1}'),
                            icon: r.$2,
                            on: r.$1 == _relation,
                            onTap: () => setState(() => _relation = r.$1),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              _Label(t('ota.phone')),
              const SizedBox(height: 8),
              _Field(
                controller: _phone,
                hint: t('ota.phoneHint'),
                maxLength: 24,
                keyboard: TextInputType.phone,
              ),

              const SizedBox(height: 16),
              _Label(t('ota.idNumber')),
              const SizedBox(height: 8),
              _Field(controller: _idNumber, hint: t('ota.idHint'), maxLength: 40),
              const SizedBox(height: 7),
              Text(
                tn('ota.idWhy', widget.child.name.split(' ').first),
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
              ),

              const SizedBox(height: 16),
              PickerField(
                label: t('ota.day'),
                value: longDate(_day),
                icon: Icons.calendar_today_rounded,
                onTap: _pickDay,
              ),

              if (widget.ridesTheBus) ...[
                const SizedBox(height: 16),
                _Label(t('ota.run')),
                const SizedBox(height: 9),
                Row(
                  children: [
                    for (final l in const ['OUT', 'RETURN']) ...[
                      Expanded(
                        child: _Choice(
                          label: t('ota.leg.$l'),
                          on: l == _leg,
                          onTap: () => setState(() => _leg = l),
                        ),
                      ),
                      if (l != 'RETURN') const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],

              if (_isToday) ...[
                const SizedBox(height: 14),
                _Warning(text: t('ota.todayUrgent')),
              ],

              const SizedBox(height: 16),
              _Label(t('ota.note')),
              const SizedBox(height: 8),
              _Field(
                controller: _note,
                hint: t('ota.notePlaceholder'),
                maxLength: 200,
                lines: 2,
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.rose, height: 1.35),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _busy || _name.text.trim().length < 2 ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: tint,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          t('ota.send'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t('ota.formFoot'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppTheme.textMuted,
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.lines = 1,
    this.autofocus = false,
    this.keyboard,
    this.capitals = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int lines;
  final bool autofocus;
  final TextInputType? keyboard;
  final TextCapitalization capitals;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        maxLength: maxLength,
        maxLines: lines,
        keyboardType: keyboard,
        textCapitalization: capitals,
        style: TextStyle(fontSize: 14, color: AppTheme.text),
        decoration: InputDecoration(
          hintText: hint,
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
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.10) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w700 : FontWeight.w600,
            color: on ? tint : AppTheme.text,
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.10) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: on ? tint : AppTheme.textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                color: on ? tint : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.priority_high_rounded, size: 17, color: AppTheme.amber),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.amber),
              ),
            ),
          ],
        ),
      );
}
