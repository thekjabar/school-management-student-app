import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import 'teacher_kit.dart';

/// A teacher's classes, and the register for one of them.
///
/// Taking the register is the only writing most teachers do in this app every
/// day, so it is one tap from the class list and saves in one call. Thirty
/// separate requests over a school's connection is thirty chances for one to
/// fail and leave a child unmarked with nobody the wiser.
/// The class list as a screen of its own.
///
/// It used to be a bottom-bar tab. The bar now carries the five destinations
/// the design asks for, so everything that was a tab and is still a place needs
/// a Scaffold of its own to be pushed onto.
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

/// The register for one class on one day.
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

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

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
    _loaderKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final absent = _marks.where((m) => m.status == 'ABSENT').length;
    final late = _marks.where((m) => m.status == 'LATE').length;
    final present = _marks.where((m) => m.status == 'PRESENT').length;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      bottomNavigationBar: _dirty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BigButton(
                  label: tn(
                    'teacher.saveTally',
                    tv('teacher.tally', {'n': present, 'a': absent, 'l': late}),
                  ),
                  color: Role.teacher.tint,
                  height: 50,
                  busy: _saving,
                  onPressed: _save,
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: widget.slot.className,
              trailing: SoftButton(
                label: shortDate(_date),
                icon: Icons.calendar_today_rounded,
                height: 40,
                onTap: _pickDate,
              ),
            ),
            Expanded(
              child: Loader<({bool alreadyTaken, List<RegisterMark> marks})>(
                key: _loaderKey,
                tint: Role.teacher.tint,
                load: () async {
                  final data = await TeacherApi.instance.register(widget.slot.classId, date: _dateString);
                  _marks = data.marks;
                  return data;
                },
                isEmpty: (d) => d.marks.isEmpty,
                empty: t('teacher.noRoster'),
                builder: (context, data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    if (data.alreadyTaken)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.greenSoft,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 17, color: AppTheme.green),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                t('teacher.registerTaken'),
                                style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.green),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.amberSoft,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_rounded, size: 17, color: AppTheme.amber),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                // Said plainly, because the screen opens with everyone
                                // showing Present and that is a default, not a record.
                                t('teacher.nothingMarked'),
                                style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ...data.marks.map(
                      (m) => _MarkRow(
                        mark: m,
                        onChanged: (status) => setState(() {
                          m.status = status;
                          if (status != 'LATE') m.minutesLate = null;
                          _dirty = true;
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
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

class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.mark, required this.onChanged});

  final RegisterMark mark;
  final ValueChanged<String> onChanged;

  // A getter, not a const: the letter on each chip is the first letter of the
  // word in the language the app is showing, and a Kurdish register marked
  // with P, A, L and E is four English initials nobody can read.
  static List<(String, String, Color, Color)> get _options => [
    ('PRESENT', t('teacher.markPresent'), AppTheme.green, AppTheme.greenSoft),
    ('ABSENT', t('teacher.markAbsent'), AppTheme.rose, AppTheme.roseSoft),
    ('LATE', t('teacher.markLate'), AppTheme.amber, AppTheme.amberSoft),
    ('EXCUSED', t('teacher.markExcused'), AppTheme.blue, AppTheme.blueSoft),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                mark.rollNumber ?? '',
                style: TextStyle(fontSize: 12, color: AppTheme.textFaint, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mark.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  Text(mark.code, style: TextStyle(fontSize: 10.5, color: AppTheme.textFaint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: _options.map((o) {
                final on = mark.status == o.$1;
                return Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: GestureDetector(
                    onTap: () => onChanged(o.$1),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? o.$3 : o.$4,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        o.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: on ? Colors.white : o.$3,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ClassRosterScreen extends StatelessWidget {
  const ClassRosterScreen({super.key, required this.slot});

  final TeachingSlot slot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: '${slot.className} · ${t('teacher.theChildren')}'),
            Expanded(
              child: Loader<List<ClassStudent>>(
                tint: Role.teacher.tint,
                load: () => TeacherApi.instance.students(slot.classId),
                isEmpty: (rows) => rows.isEmpty,
                empty: t('teacher.noRoster'),
                builder: (context, students) => Column(
                  children: [
                    const SizedBox(height: 10),
                    ...students.map(
                      (s) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Panel(
                          padding: const EdgeInsets.all(13),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Role.teacher.wash,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  s.rollNumber ?? '·',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Role.teacher.tint,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                    ),
                                    Text(
                                      s.code,
                                      style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
