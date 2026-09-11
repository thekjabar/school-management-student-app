import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';
import 'mark_bank.dart';
import 'teacher_kit.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('teacher.myClasses')),
            Expanded(
              child: const ClassesTab(),
            ),
          ],
        ),
      ),
    );
  }
}

class ClassesTab extends StatelessWidget {
  const ClassesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Loader<List<TeachingSlot>>(
      tint: Role.teacher.tint,
      load: () => TeacherApi.instance.classes(),
      isEmpty: (rows) => rows.isEmpty,
      empty: t('teacher.noClasses'),
      builder: (context, classes) => Column(
        children: [
          const SizedBox(height: 12),
          ...classes.map(
            (c) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 38,
                          decoration: BoxDecoration(
                            color: parseHex(c.colorHex, Role.teacher.tint),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.className,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tv('teacher.classMeta', {
                                      'subject': c.subjectName,
                                      'n': c.studentCount,
                                    }) +
                                    (c.room != null ? ' · ${c.room}' : ''),
                                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        if (c.isHomeroom)
                          Tag(t('teacher.homeroom'), color: Role.teacher.tint, background: Role.teacher.wash),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: BigButton(
                            label: t('teacher.takeRegister'),
                            color: Role.teacher.tint,
                            height: 44,
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => RegisterScreen(slot: c)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SoftButton(
                            label: t('teacher.theChildren'),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ClassRosterScreen(slot: c)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.slot});

  final TeachingSlot slot;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _loaderKey = GlobalKey<LoaderState<({bool alreadyTaken, List<RegisterMark> marks})>>();
  DateTime _date = DateTime.now();
  List<RegisterMark> _marks = [];
  bool _dirty = false;
  bool _saving = false;

  bool _grid = false;

  final _search = TextEditingController();
  String _query = '';
  Timer? _debounce;
  bool _searching = false;

  Set<String>? _matching;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _matching = null;
        _searching = false;
      });
      return;
    }
    setState(() => _query = value);
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searching = true);
    try {
      final data = await TeacherApi.instance.register(
        widget.slot.classId,
        date: _dateString,
        q: q,
      );
      if (!mounted || _query.trim() != q) return;
      setState(() => _matching = data.marks.map((m) => m.studentId).toSet());
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted && _query.trim() == q) setState(() => _searching = false);
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _matching = null;
      _searching = false;
    });
  }

  bool _hintDismissed = false;

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  int _count(String status) => _marks.where((m) => m.status == status).length;

  void _setStatus(RegisterMark mark, String status) {
    setState(() {
      mark.status = status;
      if (status != 'LATE') mark.minutesLate = null;
      _dirty = true;
    });
  }

  Future<void> _pickStatus(RegisterMark mark) async {
    final picked = await showAppSheet<String>(
      context,
      builder: (_) => _MarkSheet(mark: mark),
    );
    if (picked != null && mounted) _setStatus(mark, picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TeacherApi.instance.saveRegister(
        classId: widget.slot.classId,
        date: _dateString,
        marks: _marks,
      );
      if (!mounted) return;
      setState(() => _dirty = false);
      showNote(context, t('teacher.registerSaved'));
      _loaderKey.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(
      context,
      initial: _date,
      first: DateTime.now().subtract(const Duration(days: 60)),
      last: DateTime.now(),
      tint: Role.teacher.tint,
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _dirty = false;
    });
    _clearSearch();
    _loaderKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final present = _count('PRESENT');
    final absent = _count('ABSENT');
    final late = _count('LATE');
    final excused = _count('EXCUSED');

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      bottomNavigationBar: _SaveBar(
        tally: tv('teacher.tallyFull', {
          'n': present,
          'a': absent,
          'l': late,
          'e': excused,
        }),
        busy: _saving,
        onSave: _dirty ? _save : null,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _RegisterHeader(
              className: widget.slot.className,
              date: _date,
              onPickDate: _pickDate,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(kGutter, 0, kGutter, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: _onQuery,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: t('teacher.searchRegister'),
                  prefixIcon: Icon(Icons.search_rounded, size: 19, color: AppTheme.textFaint),
                  prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                  suffixIcon: _searching
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Role.teacher.tint,
                            ),
                          ),
                        )
                      : _query.isEmpty
                          ? null
                          : GestureDetector(
                              onTap: _clearSearch,
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 17,
                                color: AppTheme.textFaint,
                              ),
                            ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                ),
                  ),
                ),
                const SizedBox(width: 8),
                _ModeToggle(
                  grid: _grid,
                  onChanged: (v) => setState(() => _grid = v),
                ),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) =>
                    Loader<({bool alreadyTaken, List<RegisterMark> marks})>(
                  key: _loaderKey,
                  tint: Role.teacher.tint,
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  load: () async {
                    final data = await TeacherApi.instance.register(
                      widget.slot.classId,
                      date: _dateString,
                    );
                    _marks = data.marks;
                    if (mounted) setState(() {});
                    return data;
                  },
                  isEmpty: (d) => d.marks.isEmpty,
                  empty: t('teacher.noRoster'),
                  builder: (context, data) {
                    final matching = _matching;
                    final shown = matching == null
                        ? data.marks
                        : [for (final m in data.marks) if (matching.contains(m.studentId)) m];
                    return SizedBox(
                    height: box.maxHeight,
                    child: RefreshIndicator(
                      color: Role.teacher.tint,
                      onRefresh: () async {
                        await _loaderKey.currentState?.reload();
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                if (data.alreadyTaken) ...[
                                  NoticeBanner(
                                    icon: Icons.check_circle_rounded,
                                    title: t('teacher.registerTakenTitle'),
                                    body: t('teacher.registerTakenBody'),
                                    color: AppTheme.green,
                                  ),
                                  const SizedBox(height: kCardGap),
                                ] else if (!_hintDismissed) ...[
                                  NoticeBanner(
                                    icon: Icons.info_rounded,
                                    title: t('teacher.nothingMarkedTitle'),
                                    body: t('teacher.nothingMarkedBody'),
                                    color: AppTheme.amber,
                                    onClose: () =>
                                        setState(() => _hintDismissed = true),
                                  ),
                                  const SizedBox(height: kCardGap),
                                ],
                                _Summary(
                                  present: present,
                                  absent: absent,
                                  late: late,
                                  total: data.marks.length,
                                ),
                                if (_grid)
                                  const _GridHint()
                                else
                                  const _ColumnHeadings(),
                              ],
                            ),
                          ),
                          if (shown.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                                child: Text(
                                  t('teacher.registerNoMatch'),
                                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                ),
                              ),
                            ),
                          if (_grid)
                            SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 132,
                                mainAxisSpacing: kCardGap,
                                crossAxisSpacing: kCardGap,
                                childAspectRatio: 0.72,
                              ),
                              itemCount: shown.length,
                              itemBuilder: (context, i) {
                                final mark = shown[i];
                                return _FaceTile(
                                  mark: mark,
                                  position: data.marks.indexOf(mark) + 1,
                                  onToggle: () => _setStatus(
                                    mark,
                                    mark.status == 'ABSENT' ? 'PRESENT' : 'ABSENT',
                                  ),
                                  onPickStatus: () => _pickStatus(mark),
                                );
                              },
                            )
                          else
                            SliverList.builder(
                            itemCount: shown.length,
                            itemBuilder: (context, i) {
                              final mark = shown[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: kCardGap),
                                child: _MarkRow(
                                  mark: mark,
                                  position: data.marks.indexOf(mark) + 1,
                                  onChanged: (status) => _setStatus(mark, status),
                                ),
                              );
                            },
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
                    ),
                  );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader({
    required this.className,
    required this.date,
    required this.onPickDate,
  });

  final String className;
  final DateTime date;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(kGutter, 6, kGutter, 12),
      child: Row(
        children: [
          SquareButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.15,
                    color: AppTheme.text,
                  ),
                ),
                Text(
                  t('teacher.classAttendance'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _DatePill(date: date, onTap: onPickDate),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 8, 0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: Role.teacher.tint),
            const SizedBox(width: 7),
            Text(
              '${shortDate(date)} ${date.year}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.present,
    required this.absent,
    required this.late,
    required this.total,
  });

  final int present;
  final int absent;
  final int late;

  final int total;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Count(
              icon: Icons.check_circle_rounded,
              value: present,
              label: t('att.present'),
              color: AppTheme.green,
            ),
          ),
          Expanded(
            child: _Count(
              icon: Icons.cancel_rounded,
              value: absent,
              label: t('att.absent'),
              color: AppTheme.rose,
            ),
          ),
          Expanded(
            child: _Count(
              icon: Icons.schedule_rounded,
              value: late,
              label: t('att.late'),
              color: AppTheme.amber,
            ),
          ),
          Expanded(
            child: _Count(
              icon: Icons.groups_rounded,
              value: total,
              label: t('teacher.totalStudents'),
              color: AppTheme.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppTheme.dark ? 0.22 : 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          '$value',
          maxLines: 1,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.1,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, height: 1.3, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _ColumnHeadings extends StatelessWidget {
  const _ColumnHeadings();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: AppTheme.textFaint,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 8),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(t('teacher.colNumber'), style: style)),
          Expanded(
            child: Text(
              t('role.student').toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Text(t('teacher.attendance').toUpperCase(), style: style),
        ],
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.mark,
    required this.position,
    required this.onChanged,
  });

  final RegisterMark mark;

  final int position;

  final ValueChanged<String> onChanged;

  static List<({String status, String letter, String word, Color colour})>
      get _options => [
            (
              status: 'PRESENT',
              letter: t('teacher.markPresent'),
              word: t('att.present'),
              colour: AppTheme.green,
            ),
            (
              status: 'ABSENT',
              letter: t('teacher.markAbsent'),
              word: t('att.absent'),
              colour: AppTheme.rose,
            ),
            (
              status: 'LATE',
              letter: t('teacher.markLate'),
              word: t('att.late'),
              colour: AppTheme.amber,
            ),
            (
              status: 'EXCUSED',
              letter: t('teacher.markExcused'),
              word: t('att.excused'),
              colour: AppTheme.blue,
            ),
          ];

  @override
  Widget build(BuildContext context) {
    final options = _options;

    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Role.teacher.wash,
              shape: BoxShape.circle,
            ),
            child: Text(
              mark.rollNumber ?? '$position',
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Role.teacher.tint,
              ),
            ),
          ),
          const SizedBox(width: 7),
          CircleInitials(label: mark.name, size: 32),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mark.name,
                  maxLines: 3,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                    color: AppTheme.text,
                  ),
                ),
                Text(
                  mark.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: AppTheme.textFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            _MarkButton(
              letter: options[i].letter,
              word: options[i].word,
              colour: options[i].colour,
              chosen: mark.status == options[i].status,
              onTap: () => onChanged(options[i].status),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.letter,
    required this.word,
    required this.colour,
    required this.chosen,
    required this.onTap,
  });

  final String letter;
  final String word;
  final Color colour;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chosen
                  ? colour
                  : colour.withValues(alpha: AppTheme.dark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(12),
              boxShadow: chosen
                  ? [
                      BoxShadow(
                        color: colour.withValues(alpha: AppTheme.dark ? 0.38 : 0.24),
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              letter,
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: chosen ? Colors.white : colour,
              ),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 38,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                word,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                  height: 1.2,
                  color: chosen ? colour : AppTheme.textFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

({String letter, String word, Color colour})? _markLook(String status) {
  for (final o in _MarkRow._options) {
    if (o.status == status) {
      return (letter: o.letter, word: o.word, colour: o.colour);
    }
  }
  return null;
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.grid, required this.onChanged});

  final bool grid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            icon: Icons.view_list_rounded,
            label: t('teacher.viewList'),
            on: !grid,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 2),
          _segment(
            icon: Icons.grid_view_rounded,
            label: t('teacher.viewFaces'),
            on: grid,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required IconData icon,
    required String label,
    required bool on,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? Role.teacher.tint : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: on ? Colors.white : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridHint extends StatelessWidget {
  const _GridHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 14, 2, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.touch_app_outlined, size: 13, color: Role.teacher.tint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              t('teacher.gridHint'),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceTile extends StatelessWidget {
  const _FaceTile({
    required this.mark,
    required this.position,
    required this.onToggle,
    required this.onPickStatus,
  });

  final RegisterMark mark;

  final int position;

  final VoidCallback onToggle;
  final VoidCallback onPickStatus;

  @override
  Widget build(BuildContext context) {
    final look = _markLook(mark.status);
    final colour = look?.colour ?? AppTheme.textFaint;
    final marked = mark.status != 'PRESENT';

    return Semantics(
      button: true,
      label: '${mark.name}, ${look?.word ?? mark.status}',
      child: Material(
        color: AppTheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colour.withValues(alpha: marked ? 0.95 : 0.45),
            width: marked ? 2.4 : 1.4,
          ),
        ),
        child: InkWell(
          onTap: onToggle,
          onLongPress: onPickStatus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _FacePanel(url: mark.photoUrl),
                    if (marked)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colour.withValues(alpha: AppTheme.dark ? 0.42 : 0.30),
                        ),
                      ),
                    PositionedDirectional(
                      top: 4,
                      start: 4,
                      child: _TileChip(
                        label: mark.rollNumber ?? '$position',
                        background: AppTheme.canvas.withValues(alpha: 0.86),
                        foreground: AppTheme.textMuted,
                      ),
                    ),
                    PositionedDirectional(
                      top: 4,
                      end: 4,
                      child: _TileChip(
                        label: look?.letter ?? '?',
                        background: colour,
                        foreground: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mark.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      look?.word ?? mark.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: colour,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacePanel extends StatelessWidget {
  const _FacePanel({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const _NoFace();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _NoFace(),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(color: AppTheme.neutralSoft, child: child),
    );
  }
}

class _NoFace extends StatelessWidget {
  const _NoFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.18 : 0.10),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 22, color: AppTheme.amber),
          const SizedBox(height: 3),
          Text(
            t('teacher.noPhotoShort'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.amber,
            ),
          ),
        ],
      ),
    );
  }
}

class _TileChip extends StatelessWidget {
  const _TileChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: foreground,
        ),
      ),
    );
  }
}

class _MarkSheet extends StatelessWidget {
  const _MarkSheet({required this.mark});

  final RegisterMark mark;

  @override
  Widget build(BuildContext context) {
    final options = _MarkRow._options;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: SafeArea(
        top: false,
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
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: _FacePanel(url: mark.photoUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mark.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                          color: AppTheme.text,
                        ),
                      ),
                      Text(
                        mark.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final o in options)
                  _MarkButton(
                    letter: o.letter,
                    word: o.word,
                    colour: o.colour,
                    chosen: mark.status == o.status,
                    onTap: () => Navigator.of(context).pop(o.status),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.tally, required this.busy, required this.onSave});

  final String tally;
  final bool busy;

  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(kGutter, 10, kGutter, 10),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: busy ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: tint,
                disabledBackgroundColor: tint.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 19),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t('teacher.saveAttendance'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                tally,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClassRosterScreen extends StatefulWidget {
  const ClassRosterScreen({super.key, required this.slot});

  final TeachingSlot slot;

  @override
  State<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

class _ClassRosterScreenState extends State<ClassRosterScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<ClassStudent>>>();
  final _search = TextEditingController();

  Future<void> _recordBehaviour(BuildContext context, ClassStudent student) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => BehaviourSheet(student: student, classId: widget.slot.classId),
    );
    if (saved == true && context.mounted) {
      showNote(context, t('behaviour.saved'));
    }
  }

  Future<void> _awardMark(BuildContext context, ClassStudent student) => awardMark(
        context,
        studentId: student.studentId,
        studentName: student.name,
        classId: widget.slot.classId,
        subjectId: widget.slot.subjectId,
      );

  List<ClassStudent> _rows = const [];

  bool _searching = false;
  String _query = '';

  String? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static int _natural(String a, String b) {
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      final digitA = _isDigit(a.codeUnitAt(i));
      final digitB = _isDigit(b.codeUnitAt(j));

      if (digitA && digitB) {
        var x = i;
        var y = j;
        while (x < a.length && _isDigit(a.codeUnitAt(x))) {
          x++;
        }
        while (y < b.length && _isDigit(b.codeUnitAt(y))) {
          y++;
        }
        final numberA = _unpadded(a.substring(i, x));
        final numberB = _unpadded(b.substring(j, y));
        if (numberA.length != numberB.length) {
          return numberA.length - numberB.length;
        }
        final byValue = numberA.compareTo(numberB);
        if (byValue != 0) return byValue;
        i = x;
        j = y;
        continue;
      }

      final byLetter = a[i].toLowerCase().compareTo(b[j].toLowerCase());
      if (byLetter != 0) return byLetter;
      i++;
      j++;
    }
    return (a.length - i) - (b.length - j);
  }

  static bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

  static String _unpadded(String digits) {
    var i = 0;
    while (i < digits.length - 1 && digits.codeUnitAt(i) == 0x30) {
      i++;
    }
    return digits.substring(i);
  }

  static int _byRoster(ClassStudent a, ClassStudent b) {
    final rollA = a.rollNumber?.trim() ?? '';
    final rollB = b.rollNumber?.trim() ?? '';

    if (rollA.isEmpty != rollB.isEmpty) return rollA.isEmpty ? 1 : -1;
    if (rollA.isNotEmpty) {
      final byRoll = _natural(rollA, rollB);
      if (byRoll != 0) return byRoll;
    }

    final byCode = _natural(a.code, b.code);
    if (byCode != 0) return byCode;
    return _natural(a.name, b.name);
  }

  List<ClassStudent> get _visible {
    final wanted = _query.trim().toLowerCase();
    return _rows.where((s) {
      if (_status != null && s.status != _status) return false;
      if (wanted.isEmpty) return true;
      return s.name.toLowerCase().contains(wanted) ||
          s.code.toLowerCase().contains(wanted);
    }).toList();
  }

  List<String> get _statuses {
    final seen = <String>{};
    for (final s in _rows) {
      final value = s.status?.trim();
      if (value != null && value.isNotEmpty) seen.add(value);
    }
    final list = seen.toList()..sort(_natural);
    return list;
  }

  static String _pretty(String raw) {
    final words = raw.replaceAll('_', ' ').trim().toLowerCase();
    if (words.isEmpty) return raw;
    return words.characters.first.toUpperCase() + words.characters.skip(1).string;
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _search.clear();
        _query = '';
      }
    });
  }

  Future<void> _openFilter() async {
    final picked = await pickOne<String>(
      context,
      title: t('teacher.studentStatus'),
      tint: Role.teacher.tint,
      selected: _status ?? '',
      options: [
        PickOption(
          value: '',
          label: t('teacher.allStudents'),
          icon: Icons.groups_rounded,
        ),
        for (final status in _statuses)
          PickOption(
            value: status,
            label: _pretty(status),
            subtitle: tv('teacher.rosterCount', {
              'n': _rows.where((s) => s.status == status).length,
            }),
            icon: Icons.person_rounded,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _status = picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    final total = _rows.length;
    final narrowed = _status != null || _query.trim().isNotEmpty;
    final statuses = _statuses;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _RosterHeader(
              title: '${widget.slot.className} · ${t('teacher.theChildren')}',
              subtitle: total == 0
                  ? null
                  : narrowed
                      ? tv('teacher.rosterShowing', {'n': rows.length, 'total': total})
                      : tv('teacher.rosterCount', {'n': total}),
              searching: _searching,
              filtered: _status != null,
              onSearch: _toggleSearch,
              onFilter: statuses.length > 1 ? _openFilter : null,
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(kGutter, 0, kGutter, 10),
                child: TextField(
                  controller: _search,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  style: TextStyle(fontSize: 14, color: AppTheme.text),
                  decoration: InputDecoration(
                    hintText: t('teacher.searchRoster'),
                    prefixIcon: Icon(Icons.search_rounded, size: 19, color: AppTheme.textFaint),
                    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                    suffixIcon: _query.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: () => setState(() {
                              _search.clear();
                              _query = '';
                            }),
                            child: Icon(
                              Icons.cancel_rounded,
                              size: 17,
                              color: AppTheme.textFaint,
                            ),
                          ),
                    suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => Loader<List<ClassStudent>>(
                  key: _loaderKey,
                  tint: Role.teacher.tint,
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  load: () async {
                    final list = await TeacherApi.instance.students(widget.slot.classId);
                    list.sort(_byRoster);
                    _rows = list;
                    if (mounted) setState(() {});
                    return list;
                  },
                  isEmpty: (list) => list.isEmpty,
                  empty: t('teacher.noRoster'),
                  builder: (context, data) => SizedBox(
                    height: box.maxHeight,
                    child: RefreshIndicator(
                      color: Role.teacher.tint,
                      onRefresh: () async {
                        await _loaderKey.currentState?.reload();
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                _RosterSummary(
                                  count: total,
                                  className: widget.slot.className,
                                  subjectName: widget.slot.subjectName,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add_comment_outlined,
                                        size: 13,
                                        color: Role.teacher.tint,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          t('behaviour.rosterHint'),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            height: 1.35,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const _RosterHeadings(),
                              ],
                            ),
                          ),
                          if (rows.isEmpty)
                            SliverToBoxAdapter(
                              child: Card16(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                child: Text(
                                  t('teacher.rosterNoMatch'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                ),
                              ),
                            )
                          else
                            SliverList.builder(
                              itemCount: rows.length,
                              itemBuilder: (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: kCardGap),
                                child: _RosterRow(
                                  student: rows[i],
                                  onTap: () => _recordBehaviour(context, rows[i]),
                                  onAward: () => _awardMark(context, rows[i]),
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({
    required this.title,
    required this.subtitle,
    required this.searching,
    required this.filtered,
    required this.onSearch,
    required this.onFilter,
  });

  final String title;

  final String? subtitle;

  final bool searching;
  final bool filtered;
  final VoidCallback onSearch;

  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(kGutter, 6, kGutter, 12),
      child: Row(
        children: [
          SquareButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.15,
                    color: AppTheme.text,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SquareButton(
            icon: searching ? Icons.close_rounded : Icons.search_rounded,
            onTap: onSearch,
          ),
          if (onFilter != null) ...[
            const SizedBox(width: 8),
            SquareButton(
              icon: filtered ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              onTap: onFilter!,
            ),
          ],
        ],
      ),
    );
  }
}

class _RosterSummary extends StatelessWidget {
  const _RosterSummary({
    required this.count,
    required this.className,
    required this.subjectName,
  });

  final int count;

  final String className;
  final String subjectName;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _RosterFigure(
        icon: Icons.groups_rounded,
        value: '$count',
        label: t('teacher.students'),
        color: AppTheme.green,
      ),
      _RosterFigure(
        icon: Icons.meeting_room_rounded,
        value: className,
        label: t('teacher.classLabel'),
        color: AppTheme.violet,
      ),
      if (subjectName.trim().isNotEmpty)
        _RosterFigure(
          icon: Icons.menu_book_rounded,
          value: subjectName,
          label: t('teacher.subject'),
          color: AppTheme.blue,
        ),
    ];

    return Card16(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final cell in cells) Expanded(child: cell)],
      ),
    );
  }
}

class _RosterFigure extends StatelessWidget {
  const _RosterFigure({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppTheme.dark ? 0.22 : 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
              color: AppTheme.text,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, height: 1.3, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _RosterHeadings extends StatelessWidget {
  const _RosterHeadings();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: AppTheme.textFaint,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 8),
      child: Row(
        children: [
          SizedBox(width: 38, child: Text(t('teacher.colNumber'), style: style)),
          Expanded(
            child: Text(
              t('role.student').toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          Text(t('teacher.studentId').toUpperCase(), style: style),
        ],
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.student, this.onTap, this.onAward});

  final ClassStudent student;
  final VoidCallback? onTap;

  final VoidCallback? onAward;

  @override
  Widget build(BuildContext context) {
    return Card16(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Role.teacher.wash,
              shape: BoxShape.circle,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                student.rollNumber ?? '·',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Role.teacher.tint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          CircleInitials(label: student.name, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppTheme.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            student.code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Role.teacher.wash,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.add_comment_outlined,
                size: 15,
                color: Role.teacher.tint,
              ),
            ),
          ],
          if (onAward != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: t('bank.award'),
              child: InkWell(
                onTap: onAward,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.savings_outlined,
                    size: 15,
                    color: AppTheme.amber,
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

class BehaviourSheet extends StatefulWidget {
  const BehaviourSheet({super.key, required this.student, required this.classId});

  final ClassStudent student;
  final String? classId;

  @override
  State<BehaviourSheet> createState() => _BehaviourSheetState();
}

class _BehaviourSheetState extends State<BehaviourSheet> {
  String _kind = 'MERIT';
  String? _category;
  final _note = TextEditingController();
  bool _tellFamily = false;
  bool _busy = false;
  String? _error;

  static const _merit = ['ACADEMIC_EFFORT', 'ACADEMIC_EXCELLENCE', 'HELPFULNESS', 'ATTENDANCE'];
  static const _concern = [
    'DISRUPTION',
    'HOMEWORK',
    'UNIFORM',
    'DISRESPECT',
    'PHONE_OR_DEVICE',
    'BUS_CONDUCT',
    'PROPERTY_DAMAGE',
    'BULLYING',
    'VIOLENCE',
  ];

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await TeacherApi.instance.recordBehaviour(
        studentId: widget.student.studentId,
        kind: _kind,
        classId: widget.classId,
        category: _category,
        points: _kind == 'MERIT' ? 1 : -1,
        note: _note.text,
        visibleToGuardian: _tellFamily,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final merit = _kind == 'MERIT';
    final colour = merit ? AppTheme.green : AppTheme.amber;
    final categories = merit ? _merit : _concern;

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
                widget.student.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _KindTile(
                      label: t('behaviour.merit'),
                      icon: Icons.star_rounded,
                      colour: AppTheme.green,
                      on: merit,
                      onTap: () => setState(() {
                        _kind = 'MERIT';
                        _category = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _KindTile(
                      label: t('behaviour.concern'),
                      icon: Icons.error_outline_rounded,
                      colour: AppTheme.amber,
                      on: !merit,
                      onTap: () => setState(() {
                        _kind = 'CONCERN';
                        _category = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text(
                t('behaviour.what'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in categories)
                    InkWell(
                      onTap: () => setState(() => _category = _category == c ? null : c),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        decoration: BoxDecoration(
                          color: _category == c
                              ? colour.withValues(alpha: 0.12)
                              : AppTheme.canvas,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _category == c ? colour : AppTheme.border,
                            width: _category == c ? 1.4 : 1,
                          ),
                        ),
                        child: Text(
                          t('behaviour.cat.$c'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _category == c ? FontWeight.w700 : FontWeight.w500,
                            color: _category == c ? colour : AppTheme.text,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: InputDecoration(
                  hintText: t('behaviour.noteHint'),
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
              const SizedBox(height: 6),

              SwitchListTile.adaptive(
                value: _tellFamily,
                onChanged: (v) => setState(() => _tellFamily = v),
                activeThumbColor: tint,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t('behaviour.tellFamily'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                subtitle: Text(
                  _tellFamily
                      ? t('behaviour.tellFamilyOn')
                      : t('behaviour.tellFamilyOff'),
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.rose),
                ),
              ],

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: colour,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          t('behaviour.save'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.label,
    required this.icon,
    required this.colour,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? colour.withValues(alpha: 0.12) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? colour : AppTheme.border, width: on ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: on ? colour : AppTheme.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: on ? colour : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
