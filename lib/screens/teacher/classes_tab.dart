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
///
/// A page rather than a form: which class and which day at the top, where the
/// class stands right now under it, then one card per child carrying the four
/// marks. Nothing about what this screen DOES changed with the redesign — the
/// whole register still saves in one call, a day that has already been taken
/// still says so before anything is touched, and a register nobody has marked
/// still cannot be saved by accident.
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

  final _search = TextEditingController();
  String _query = '';
  Timer? _debounce;
  bool _searching = false;

  /// The children the server said match the search, or null when there is
  /// no search. Only ids come back into use: the rows drawn are still the
  /// ones in [_marks], so a mark put against a child before the teacher
  /// searched is still there when the search is cleared. Re-fetching the
  /// rows themselves would wipe every unsaved mark on each keystroke.
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
    // A pause, not a keystroke: a teacher typing a name sends one request for
    // the name, not one for every letter of it.
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
      // Typed past this one while it was in flight; the newer search answers.
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

  /// Whether the amber note has been waved away.
  ///
  /// Dismissed for the sitting rather than for the day: it is a reminder, not a
  /// record, and a teacher working down a class of fifty does not need telling
  /// twice that nothing is marked yet.
  bool _hintDismissed = false;

  String get _dateString =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  /// How many children carry one mark.
  ///
  /// Every figure on this screen is counted from the marks in hand rather than
  /// from a total the server sent, because the moment a teacher taps a letter
  /// the two disagree and the one on screen is the true one.
  int _count(String status) => _marks.where((m) => m.status == status).length;

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
      // Fixed, rather than appearing the moment the register turns dirty: a bar
      // that arrives from nowhere shifts the class list under the finger that
      // is marking it. It stays disabled until something has actually been
      // marked, which is the protection the appearing bar used to give — an
      // untouched register saved by mistake marks the whole class present.
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
            Expanded(
              // The height of the region is measured here so the body can fill
              // it exactly and scroll its own children lazily. Fifty is an
              // ordinary class in these schools, and fifty cards in one column
              // is fifty cards laid out again on every single tap.
              child: LayoutBuilder(
                builder: (context, box) =>
                    Loader<({bool alreadyTaken, List<RegisterMark> marks})>(
                  key: _loaderKey,
                  tint: Role.teacher.tint,
                  // Horizontal only. Vertical padding here would make the
                  // loader's own list taller than the screen, and then two
                  // things would scroll where there should be one.
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  load: () async {
                    final data = await TeacherApi.instance.register(
                      widget.slot.classId,
                      date: _dateString,
                    );
                    _marks = data.marks;
                    // The loader rebuilds only itself when the fetch lands, and
                    // the summary and the tally under the save button are drawn
                    // from this state — without this they would sit at zero
                    // until the first child was marked.
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
                      // The loader's own pull-to-refresh only hears the list it
                      // owns, and the list under a teacher's thumb is this one.
                      // Same gesture, same reload.
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
                                    // Said plainly, because the screen opens
                                    // with everyone showing Present and that is
                                    // a default, not a record.
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
                          SliverList.builder(
                            itemCount: shown.length,
                            itemBuilder: (context, i) {
                              final mark = shown[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: kCardGap),
                                child: _MarkRow(
                                  mark: mark,
                                  // Where the child sits in the whole register,
                                  // not in the search results: the number next
                                  // to a name must not change when the teacher
                                  // types.
                                  position: data.marks.indexOf(mark) + 1,
                                  onChanged: (status) => setState(() {
                                    mark.status = status;
                                    if (status != 'LATE') mark.minutesLate = null;
                                    _dirty = true;
                                  }),
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

/// Back, which class, which day.
///
/// Not [ScreenHeader]: this one carries a second line under the title saying
/// what the page is, and a control on the right that is a pill rather than a
/// square. Everything else about it — the white tile, the gutter, the weight of
/// the title — is that header's, so the two read as the same furniture.
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

/// The day, and a way to change it.
///
/// The chevron is drawn because the day really is switchable: the register
/// endpoint takes a date, the picker the rest of the app already uses returns
/// one, and the loader refetches for whichever day comes back.
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

/// Where the class stands, counted from the marks on screen.
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

  /// The roster length, which is the only total there is — nothing on this
  /// screen knows how many children the class is supposed to have.
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

/// What the three columns of the list below are.
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

/// One child, and the four marks that can be put against them.
class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.mark,
    required this.position,
    required this.onChanged,
  });

  final RegisterMark mark;

  /// Where in the list this child sits. Shown only when the school has given
  /// the child no roll number of their own: an invented number in the column a
  /// teacher reads as the roll is worse than no number at all.
  final int position;

  final ValueChanged<String> onChanged;

  // A getter, not a const: the letter on each button is the first letter of the
  // word in the language the app is showing, and a Kurdish register marked with
  // P, A, L and E is four English initials nobody can read.
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
          // The name gives up its width first: the four marks are what the
          // screen is for, and a long name that pushed them past the edge would
          // leave a child unmarkable. It wraps rather than truncates — a
          // Kurdish name is three words and the third is the one that tells
          // two cousins apart, so "Shadan Ja…" is not a name, it is a guess.
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

/// One of the four marks: the letter, and the word it stands for.
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
              // The ring, so which mark is chosen is legible to somebody who
              // cannot tell the four colours apart.
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

/// The bar the register is saved from.
///
/// Drawn here rather than with [BigButton] because it carries three things at
/// once — a glyph, the action, and a live count of what is about to be written
/// — and BigButton is one centred label by design. The radius, the fill and the
/// busy spinner are BigButton's, so the two still match.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.tally, required this.busy, required this.onSave});

  final String tally;
  final bool busy;

  /// Null until something has been marked, which is what stops an untouched
  /// register being written as a class full of present children.
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

/// Who is in this class, in the order a register is read.
///
/// The list arrived from the server sorted as TEXT, which is why the owner's
/// screenshot runs 1, 10, 11 … 18, 2, 3: "10" is before "2" alphabetically and
/// so is "S0010" before "S0002". Nothing on this screen can make the server
/// order its rows, so the order is imposed here, on every load, before anything
/// is drawn — see [_byRoster]. A teacher scanning a register cannot use a list
/// that jumps from 1 to 10.
class ClassRosterScreen extends StatefulWidget {
  const ClassRosterScreen({super.key, required this.slot});

  final TeachingSlot slot;

  @override
  State<ClassRosterScreen> createState() => _ClassRosterScreenState();
}

class _ClassRosterScreenState extends State<ClassRosterScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<ClassStudent>>>();
  final _search = TextEditingController();

  /// The roster as it arrived, already ordered.
  ///
  /// Held here as well as inside the loader because the header counts it, and
  /// because the filter tile has to know whether there is anything to filter BY
  /// before it decides to exist at all.
  List<ClassStudent> _rows = const [];

  bool _searching = false;
  String _query = '';

  /// The status being filtered to, or null for everybody. Only ever one of the
  /// values the server actually sent for this class — see [_statuses].
  String? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /* ---- Order ------------------------------------------------------------ */

  /// Compare two identifiers the way a person reads them.
  ///
  /// Walks both strings in runs of digits and runs of everything else, and
  /// compares a digit run by its VALUE rather than its spelling. So S0002 lands
  /// after S0001, S0010 after S0009, and 10 after 9 — none of which plain
  /// string comparison manages.
  ///
  /// The digit run is compared by length-then-text with leading zeros stripped
  /// rather than parsed into an int: a code long enough to overflow one is
  /// still a code, and a school that numbers its children 000000001 is not a
  /// school this should give up on.
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
    // One is a prefix of the other: the shorter goes first.
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

  /// Roll number first, code second.
  ///
  /// The roll is the number the school itself put on the child and the one
  /// printed in the paper register, so it wins wherever it exists. A child the
  /// school has given no roll goes to the END of the list rather than being
  /// wedged between two numbered ones by their code — where they would look
  /// like a gap in the numbering rather than an absence of it.
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

  /* ---- What is on screen ------------------------------------------------ */

  List<ClassStudent> get _visible {
    final wanted = _query.trim().toLowerCase();
    return _rows.where((s) {
      if (_status != null && s.status != _status) return false;
      if (wanted.isEmpty) return true;
      return s.name.toLowerCase().contains(wanted) ||
          s.code.toLowerCase().contains(wanted);
    }).toList();
  }

  /// The distinct statuses THIS class's roster actually carries.
  ///
  /// The filter is built from the payload in hand rather than from a list of
  /// states somebody once wrote down, so it can only ever offer a choice that
  /// has at least one child behind it. Fewer than two and there is nothing to
  /// choose between, and the tile is not drawn at all.
  List<String> get _statuses {
    final seen = <String>{};
    for (final s in _rows) {
      final value = s.status?.trim();
      if (value != null && value.isNotEmpty) seen.add(value);
    }
    final list = seen.toList()..sort(_natural);
    return list;
  }

  /// A server word, made presentable — and deliberately NOT translated.
  ///
  /// The roster's status is an enum this app has never been given the
  /// vocabulary of, so there is no key to look it up under; inventing labels
  /// for values nobody has seen would be inventing data. Underscores become
  /// spaces and SHOUTING becomes a word, which is as far as it is safe to go.
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
      // The empty string is "everybody". pickOne returns null for a sheet that
      // was dismissed, so null cannot also mean a choice.
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
              // Nothing at all until the roster has landed. "0 students" under
              // the title of a class that has thirty is a figure, and a wrong
              // one; a blank line is simply the count not being known yet.
              subtitle: total == 0
                  ? null
                  : narrowed
                      ? tv('teacher.rosterShowing', {'n': rows.length, 'total': total})
                      : tv('teacher.rosterCount', {'n': total}),
              searching: _searching,
              filtered: _status != null,
              onSearch: _toggleSearch,
              // Drawn ONLY when this roster carries two or more different
              // statuses. Everything else the payload holds — name, code, roll
              // number — is what the search field is for, and a filter tile
              // that opens onto one option, or onto nothing, is a button that
              // lies about having something behind it.
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
              // The height of the region is measured here so the body can fill
              // it exactly and scroll its own children lazily. Fifty is an
              // ordinary class in these schools, and fifty cards in one column
              // is fifty cards laid out again on every keystroke in the search
              // field.
              child: LayoutBuilder(
                builder: (context, box) => Loader<List<ClassStudent>>(
                  key: _loaderKey,
                  tint: Role.teacher.tint,
                  // Horizontal only: vertical padding here would make the
                  // loader's own list taller than the screen, and then two
                  // things would scroll where there should be one.
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  load: () async {
                    final list = await TeacherApi.instance.students(widget.slot.classId);
                    // Defensively, every time. The order the rows arrive in is
                    // the server's business and it has been wrong; this is the
                    // one place that can guarantee what the teacher sees.
                    list.sort(_byRoster);
                    _rows = list;
                    // The loader rebuilds only itself when the fetch lands, and
                    // the header's count and the filter tile are drawn from
                    // this state — without this the title would sit alone and
                    // the filter would never appear.
                    if (mounted) setState(() {});
                    return list;
                  },
                  isEmpty: (list) => list.isEmpty,
                  empty: t('teacher.noRoster'),
                  builder: (context, data) => SizedBox(
                    height: box.maxHeight,
                    child: RefreshIndicator(
                      color: Role.teacher.tint,
                      // The loader's own pull-to-refresh only hears the list it
                      // owns, and the list under a teacher's thumb is this one.
                      // Same gesture, same reload.
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
                                child: _RosterRow(student: rows[i]),
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

/// Back, which class, how many — and the two things that can be done to the
/// list underneath.
///
/// Not [ScreenHeader]: this one carries a second line under the title, and up
/// to two controls after it. Everything else about it — the tile, the gutter,
/// the weight of the title — is that header's, and [_RegisterHeader]'s, so the
/// three read as the same furniture.
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

  /// Null until the roster has arrived — the count is not known before then,
  /// and a zero would be a wrong figure rather than a missing one.
  final String? subtitle;

  final bool searching;
  final bool filtered;
  final VoidCallback onSearch;

  /// Null when this roster has nothing to filter by, and then no tile is drawn.
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
            // The glyph says what the tap does NEXT: a second press on an open
            // search closes it and puts the whole class back.
            icon: searching ? Icons.close_rounded : Icons.search_rounded,
            onTap: onSearch,
          ),
          if (onFilter != null) ...[
            const SizedBox(width: 8),
            SquareButton(
              // Filled while a filter is on, so a teacher who cannot find a
              // child can see WHY the list is short. A count badge here would
              // be a number about nothing.
              icon: filtered ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              onTap: onFilter!,
            ),
          ],
        ],
      ),
    );
  }
}

/// The class in figures.
///
/// Three, not the four the design draws. The fourth and fifth cells were Boys
/// and Girls, and the roster payload carries no sex or gender field — only an
/// id, a code, a name, a roll number and a status. Guessing it from first names
/// would be a figure the school never gave us, printed in a card that looks
/// like a record.
class _RosterSummary extends StatelessWidget {
  const _RosterSummary({
    required this.count,
    required this.className,
    required this.subjectName,
  });

  /// The roster length, which is the only total there is — nothing on this
  /// screen knows how many children the class is supposed to have.
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

/// One figure: a circular tinted glyph, the value, and what it is.
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
        // Scaled down rather than clipped: a class called "Grade 5 — B" and a
        // subject called "Mathematics" are both wider than a third of a phone,
        // and a value reading "Mathema…" answers nothing.
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

/// What the three columns of the list below are.
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

/// One child on the roster.
class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.student});

  final ClassStudent student;

  @override
  Widget build(BuildContext context) {
    return Card16(
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
                // The school's own roll number, or a dot where it has given
                // none. The position in the list would look like a roll number
                // and would not be one — and a made-up number in the column a
                // teacher reads as the roll is worse than no number at all.
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
          // No tint, matching the register one screen away.
          //
          // The rule elsewhere in this app is to pass a tint, because an
          // untinted avatar hashes the name into its own hue and a lone pink
          // circle in a violet app looks like a mistake. A ROSTER is the case
          // that rule was not written for: eighteen children in a column, and
          // the hash is what lets a teacher find the same child by colour on
          // both screens. Two treatments one screen apart is the bug, not the
          // hue.
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
        ],
      ),
    );
  }
}
