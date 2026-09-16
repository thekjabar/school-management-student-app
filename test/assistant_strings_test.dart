import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/assistant_screen.dart';
import 'package:student_app/screens/teacher/assistant_screen.dart';
import 'package:student_app/ui/assistant_kit.dart';
import 'package:student_app/ui/format.dart';

const _parentKeys = <String>[
  'quick.assistant',
  'ai.title',
  'ai.tab.question',
  'ai.tab.report',
  'ai.questionLead',
  'ai.reportLead',
  'ai.questionHint',
  'ai.reportHint',
  'ai.ask',
  'ai.thinking',
  'ai.left',
  'ai.spent',
  'ai.spentUntil',
  'ai.nothingAsked',
  'ai.scopeNote',
  'ai.unavailable',
];

const _teacherKeys = <String>[
  'teacher.assistant',
  'tai.title',
  'tai.tab.question',
  'tai.tab.classReport',
  'tai.tab.studentReport',
  'tai.questionLead',
  'tai.classLead',
  'tai.studentLead',
  'tai.questionHint',
  'tai.classHint',
  'tai.studentHint',
  'tai.pickClass',
  'tai.pickStudent',
  'tai.chooseClass',
  'tai.chooseStudent',
  'tai.noClasses',
  'tai.ask',
  'tai.thinking',
  'tai.left',
  'tai.spent',
  'tai.spentUntil',
  'tai.nothingAsked',
  'tai.scopeNote',
  'tai.unavailable',
];

const _outcomes = <String>[
  'ANSWERED',
  'REFUSED_OFF_TOPIC',
  'REFUSED_OUT_OF_SCOPE',
  'BLOCKED_BY_LIMIT',
  'BLOCKED_PERSON',
  'PROVIDER_ERROR',
  'UNAVAILABLE',
];

const _historyKeys = <String>[
  'aih.past',
  'aih.note',
  'aih.loadingOlder',
  'aih.failed',
  'aih.allChildren',
  'aih.allClasses',
];

const _grumble = 'You exceeded your current quota, please check your plan and billing details.';

Map<String, dynamic> _parentRow({String outcome = 'ANSWERED'}) => {
      'id': 'cmai00000000000000000001',
      'at': '2026-09-16T09:00:00.000Z',
      'kind': 'CHILD_REPORT',
      'outcome': outcome,
      'lang': 'ckb',
      'question': 'How is my child doing?',
      'truncated': false,
      'child': {
        'studentId': 'cmstudent000000000000001',
        'name': 'Lana Aram Kaka',
        'names': {'ckb': 'لانە ئارام کاکە', 'ar': null, 'en': 'Lana Aram Kaka'},
      },
      'schoolClass': {
        'id': 'cmclass000000000000000a1',
        'name': 'پۆلی ٤',
        'names': {'ckb': 'پۆلی ٤', 'ar': null, 'en': 'Grade 4'},
      },
      'subject': null,
    };

Map<String, dynamic> _teacherRow() => {
      'id': 'cmai00000000000000000002',
      'at': '2026-09-16T10:00:00.000Z',
      'kind': 'CLASS_REPORT',
      'outcome': 'ANSWERED',
      'lang': 'en',
      'question': 'How is my class doing?',
      'truncated': false,
      'pupil': {
        'studentId': 'cmstudent000000000000002',
        'name': 'Dara Sami Baban',
        'names': {'ckb': null, 'ar': null, 'en': 'Dara Sami Baban'},
      },
      'schoolClass': null,
      'subject': null,
    };

AiChildAllowance _allowance({required int remaining, String? resetsOn}) => AiChildAllowance(
      studentId: 'cmstudent000000000000001',
      name: 'Child',
      limit: 3,
      remaining: remaining,
      resetsOn: resetsOn,
    );

void main() {
  tearDown(() => AppLocale.current.value = Lang.en);

  test('every assistant phrase exists in all three languages', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final key in [..._parentKeys, ..._teacherKeys]) {
        expect(
          tableFor(lang).containsKey(key),
          isTrue,
          reason: '$key is missing from ${lang.code}, so the screen would fall back to English',
        );
        expect(t(key), isNot(key), reason: '$key would print its own name in ${lang.code}');
        expect(t(key).trim(), isNotEmpty, reason: '$key is blank in ${lang.code}');
      }
    }
  });

  test('the family is told plainly what is left, and when more comes back', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;

      final some = allowanceLine(_allowance(remaining: 2));
      expect(some, contains('2'));
      expect(some, contains('3'));
      expect(some, isNot(contains('{')), reason: 'a hole was left in ${lang.code}: $some');

      final gone = allowanceLine(_allowance(remaining: 0, resetsOn: '17 September'));
      expect(gone, contains('17 September'), reason: 'the reset day went missing in ${lang.code}');
      expect(gone, isNot(contains('{')));

      final goneNoDate = allowanceLine(_allowance(remaining: 0));
      expect(goneNoDate.trim(), isNotEmpty);
      expect(goneNoDate, isNot(contains('{')));

      expect(allowanceLine(null), isEmpty);
    }
  });

  test('the teacher is told the same, in their own language', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;

      final some = teacherAllowanceLine(4, 5, null);
      expect(some, contains('4'));
      expect(some, contains('5'));
      expect(some, isNot(contains('{')), reason: 'a hole was left in ${lang.code}: $some');

      final gone = teacherAllowanceLine(0, 5, '17 September');
      expect(gone, contains('17 September'));
      expect(gone, isNot(contains('{')));

      expect(teacherAllowanceLine(0, 5, null), isNot(contains('{')));
    }
  });

  test('both screens tell the reader, unasked, what the assistant will not answer', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final key in ['ai.scopeNote', 'tai.scopeNote']) {
        expect(t(key).trim().length, greaterThan(12), reason: '$key says too little in ${lang.code}');
      }
    }
  });

  test('the assistant is a switchable section, not a hard-coded feature', () {
    expect(ParentSection.ai, 'parent.ai');
  });

  test('the family sees the assistant before the school chat', () {
    final home = File('lib/screens/parent/home_tab.dart').readAsStringSync();
    final assistant = home.indexOf("t('quick.assistant')");
    final chat = home.indexOf("t('quick.conversations')");

    expect(assistant, greaterThan(-1), reason: 'the assistant tile is not on the parent home');
    expect(chat, greaterThan(-1));
    expect(assistant, lessThan(chat), reason: 'the assistant tile must come before the school chat tile');
  });

  test('every phrase the past questions need exists in all three languages', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final key in [..._historyKeys, for (final o in _outcomes) 'aih.outcome.$o']) {
        expect(
          tableFor(lang).containsKey(key),
          isTrue,
          reason: '$key is missing from ${lang.code}, so the reader would be shown English',
        );
        expect(t(key).trim(), isNotEmpty, reason: '$key is blank in ${lang.code}');
      }
    }
  });

  test('a question that got no answer is told as an outcome, never as a raw code', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final outcome in _outcomes) {
        final word = outcomeWord(outcome);
        expect(word, isNot(outcome), reason: '$outcome printed its own code in ${lang.code}');
        expect(word, isNot(contains('_')), reason: '$outcome kept an underscore in ${lang.code}');
        expect(word.trim(), isNotEmpty);
      }
    }
  });

  test('a past question reads the same whether the parent or the teacher asked it', () {
    final mine = AiHistoryRow.fromJson(_parentRow());
    expect(mine.id, 'cmai00000000000000000001');
    expect(mine.kind, 'CHILD_REPORT');
    expect(mine.answered, isTrue);
    expect(mine.person?.id, 'cmstudent000000000000001');
    expect(mine.schoolClass?.id, 'cmclass000000000000000a1');
    expect(mine.at?.toUtc(), DateTime.utc(2026, 9, 16, 9));

    final theirs = AiHistoryRow.fromJson(_teacherRow());
    expect(theirs.person?.id, 'cmstudent000000000000002');
    expect(theirs.schoolClass, isNull);
  });

  test('the child is named in the reader’s own language', () {
    final row = AiHistoryRow.fromJson(_parentRow());

    AppLocale.current.value = Lang.ckb;
    expect(row.person?.label, 'لانە ئارام کاکە');

    AppLocale.current.value = Lang.en;
    expect(row.person?.label, 'Lana Aram Kaka');
  });

  test('what went wrong inside the assistant can never reach the reader', () {
    final leaked = {..._parentRow(outcome: 'PROVIDER_ERROR'), 'answer': null, 'failure': _grumble};
    final entry = AiHistoryEntry.fromJson(leaked);

    expect(entry.answer, isNull);
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      final shown = entry.answer ?? outcomeWord(entry.row.outcome);
      expect(shown, isNot(contains('quota')), reason: 'the provider’s words showed in ${lang.code}');
      expect(shown, isNot(contains(_grumble)));
      expect(shown, t('aih.outcome.PROVIDER_ERROR'));
    }
  });

  test('a page of past questions carries its own place in the walk backwards', () {
    final page = AiHistoryPage.fromJson({
      'rows': [_parentRow(), _teacherRow()],
      'hasMore': true,
      'nextCursor': 'eyJ0IjoiMjAyNi0wOS0xNiJ9',
    });

    expect(page.rows.map((r) => r.id), [
      'cmai00000000000000000001',
      'cmai00000000000000000002',
    ]);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'eyJ0IjoiMjAyNi0wOS0xNiJ9');
    expect(AiHistoryPage.empty.rows, isEmpty);
    expect(AiHistoryPage.empty.hasMore, isFalse);
  });

  test('the meta line tells when, how it ended and who it was about, with no holes', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      final row = AiHistoryRow.fromJson(_parentRow());
      final line = historyMeta(row, t('ai.tab.report'));

      expect(line, contains(hhmm(row.at)), reason: 'the reader is not told the hour in their own clock');
      expect(line, contains(t('aih.outcome.ANSWERED')));
      expect(line, contains(t('ai.tab.report')));
      expect(line, isNot(contains('{')), reason: 'a hole was left in ${lang.code}: $line');
    }
  });

  test('each screen asks only its own audience’s history route', () {
    final parent = File('lib/screens/parent/assistant_screen.dart').readAsStringSync();
    final teacher = File('lib/screens/teacher/assistant_screen.dart').readAsStringSync();

    expect(parent.contains('TeacherApi'), isFalse, reason: 'the parent screen reaches a teacher route');
    expect(teacher.contains('ParentApi'), isFalse, reason: 'the teacher screen reaches a parent route');

    final api = File('lib/api/parent_api.dart').readAsStringSync();
    final tapi = File('lib/api/teacher_api.dart').readAsStringSync();
    expect(api.contains("'/parent/ai/history"), isTrue);
    expect(tapi.contains("'/teacher/ai/history"), isTrue);
    expect(api.contains('/teacher/ai/history'), isFalse);
    expect(tapi.contains('/parent/ai/history'), isFalse);
  });

  test('no provider key can reach the app', () {
    final lib = Directory('lib').listSync(recursive: true).whereType<File>().where(
          (f) => f.path.endsWith('.dart'),
        );
    for (final file in lib) {
      final source = file.readAsStringSync();
      for (final banned in ['GEMINI_API_KEY', 'GROQ_API_KEY', 'generativelanguage.googleapis.com', 'api.groq.com']) {
        expect(
          source.contains(banned),
          isFalse,
          reason: '${file.path} names $banned; every model call must stay on our server',
        );
      }
    }
  });
}
