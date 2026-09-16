import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/assistant_screen.dart';
import 'package:student_app/screens/teacher/assistant_screen.dart';

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
