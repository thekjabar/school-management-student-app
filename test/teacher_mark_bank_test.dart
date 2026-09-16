import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/teacher_api.dart';
import 'package:student_app/i18n/strings.dart';

void main() {
  Map<String, dynamic> entry(Map<String, dynamic> over) => <String, dynamic>{
        'id': 'cmbank0000000000000000001',
        'studentId': 'cmstud0000000000000000001',
        'studentName': 'Aram',
        'points': 3,
        'reason': 'Helped a classmate',
        'occurredAt': '2026-09-15T09:00:00.000Z',
        'state': 'BANKED',
        'classId': 'cmclass000000000000000001',
        'subjectId': 'cmsubj0000000000000000001',
        'awaitingApproval': false,
        ...over,
      };

  test('banked credit is spendable, credit sent to the principal is not', () {
    expect(MarkBankEntry.fromJson(entry(const {})).canSpend, isTrue);
    expect(
      MarkBankEntry.fromJson(entry(const {'awaitingApproval': true})).canSpend,
      isFalse,
    );
    expect(MarkBankEntry.fromJson(entry(const {'state': 'REDEEMED'})).canSpend, isFalse);
    expect(MarkBankEntry.fromJson(entry(const {'state': 'VOIDED'})).canSpend, isFalse);
  });

  test('a mark bank entry keeps the class and subject the award needs', () {
    final e = MarkBankEntry.fromJson(entry(const {
      'points': '2.5',
      'subject': {'name': 'Maths'},
      'term': {'name': 'Term 1'},
    }));
    expect(e.points, 2.5);
    expect(e.classId, 'cmclass000000000000000001');
    expect(e.subjectId, 'cmsubj0000000000000000001');
    expect(e.subjectName, 'Maths');
    expect(e.termName, 'Term 1');
  });

  test('the school rules say who awards and which subjects are covered', () {
    final open = MarkBankRules.fromJson(const {
      'enabled': true,
      'maxPointsPerEntry': 5,
      'maxBankedPerStudentPerTerm': 20,
      'maxAddedToMark': 5,
      'approvalMode': 'TEACHER',
      'allSubjects': true,
      'subjectIds': [],
      'pointSteps': [-1, 1, 2, 3, 5],
    });
    expect(open.principalApproves, isFalse);
    expect(open.covers('cmsubj0000000000000000009'), isTrue);
    expect(open.pointSteps, [-1, 1, 2, 3, 5]);

    final narrow = MarkBankRules.fromJson(const {
      'enabled': true,
      'approvalMode': 'PRINCIPAL',
      'allSubjects': false,
      'subjectIds': ['cmsubj0000000000000000001'],
      'pointSteps': [1, 2],
    });
    expect(narrow.principalApproves, isTrue);
    expect(narrow.covers('cmsubj0000000000000000001'), isTrue);
    expect(narrow.covers('cmsubj0000000000000000002'), isFalse);
    expect(narrow.covers(null), isFalse);
  });

  test('a school that never opened the rules reads as off, not as open', () {
    final none = MarkBankRules.fromJson(const {});
    expect(none.enabled, isFalse);
    expect(none.maxAddedToMark, 0);
    expect(none.principalApproves, isFalse);
  });

  test('the preview says what is lost to the school limit', () {
    final capped = AwardPreview.fromJson(const {
      'kind': 'TERM_MARK',
      'bankedPoints': 12,
      'pointsToAward': 5,
      'cappedByMarkLimit': true,
      'cappedByMaxScore': false,
      'needsApproval': false,
      'entryCount': 4,
      'scoreBefore': 70,
      'scoreAfter': 75,
    });
    expect(capped.capped, isTrue);
    expect(capped.pointsLost, 7);
    expect(capped.canGo, isTrue);
    expect(capped.scoreAfter, 75);
  });

  test('a refused preview can never be sent, whatever the points say', () {
    final refused = AwardPreview.fromJson(const {
      'kind': 'TERM_MARK',
      'bankedPoints': 6,
      'pointsToAward': 6,
      'refusal': 'MARKS_LOCKED',
    });
    expect(refused.canGo, isFalse);

    final nothingLeft = AwardPreview.fromJson(const {
      'kind': 'TERM_MARK',
      'bankedPoints': 6,
      'pointsToAward': 0,
    });
    expect(nothingLeft.canGo, isFalse);
  });

  test('an award waiting on the principal is not an award yet', () {
    final waiting = MarkBankAward.fromJson(const {
      'id': 'cmaward00000000000000001',
      'studentId': 'cmstud0000000000000000001',
      'studentName': 'Aram',
      'kind': 'TERM_MARK',
      'status': 'PROPOSED',
      'points': 4,
      'reason': 'Steady effort all term',
      'entryCount': 2,
    });
    expect(waiting.isWaiting, isTrue);
    expect(waiting.isApplied, isFalse);
    expect(waiting.canUndo, isTrue);

    final given = MarkBankAward.fromJson(const {
      'id': 'cmaward00000000000000002',
      'status': 'APPLIED',
      'points': 4,
      'scoreBefore': 70,
      'scoreAfter': 74,
    });
    expect(given.isApplied, isTrue);
    expect(given.isWaiting, isFalse);
    expect(given.scoreAfter, 74);

    final undone = MarkBankAward.fromJson(const {
      'id': 'cmaward00000000000000003',
      'status': 'REVERSED',
      'reversedReason': 'Entered on the wrong child',
    });
    expect(undone.canUndo, isFalse);
    expect(undone.reversedReason, 'Entered on the wrong child');
  });

  test('every award word the teacher can meet has all three languages', () {
    const keys = [
      'bank.privateBody',
      'bank.privateLedger',
      'bank.awardExplains',
      'bank.awardTitle',
      'bank.awardBody',
      'bank.whatChanges',
      'bank.meritOf',
      'bank.spends',
      'bank.capLoses',
      'bank.awardWhy',
      'bank.giveIt',
      'bank.sendToHead',
      'bank.headMustAgree',
      'bank.sentToHead',
      'bank.awardedNote',
      'bank.waitingOnHead',
      'bank.proposeN',
      'bank.awardN',
      'bank.editTitle',
      'bank.editBody',
      'bank.saveChange',
      'bank.changedNote',
      'bank.kind.TERM_MARK',
      'bank.kind.MERIT',
      'bank.kindBody.TERM_MARK',
      'bank.kindBody.MERIT',
      'bank.state.BANKED',
      'bank.state.REDEEMED',
      'bank.state.VOIDED',
      'bank.state.EXPIRED',
      'bank.refusal.MARK_BANK_OFF',
      'bank.refusal.NOTHING_TO_AWARD',
      'bank.refusal.NO_TERM_MARK',
      'bank.refusal.MARKS_LOCKED',
      'bank.refusal.MARK_ALREADY_FULL',
      'bank.refusal.NO_ROOM_LEFT_ON_MARK',
    ];
    for (final lang in Lang.values) {
      final table = tableFor(lang);
      for (final key in keys) {
        expect(table[key], isNotNull, reason: '$key missing in ${lang.code}');
        expect(table[key], isNot(key), reason: '$key unset in ${lang.code}');
      }
    }
  });

  test('the wording the teacher reads carries the numbers it promises', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      expect(tv('bank.giveIt', {'points': '+5'}), contains('+5'));
      expect(tv('bank.meritOf', {'points': '5'}), contains('5'));
      expect(
        tv('bank.spends', {'n': 3, 'points': '5'}),
        allOf(contains('3'), contains('5')),
      );
      expect(tv('bank.capLoses', {'points': '+7'}), contains('+7'));
      expect(
        tv('bank.awardTitle', {'name': 'Aram', 'points': '+4'}),
        allOf(contains('Aram'), contains('+4')),
      );
      expect(
        tv('bank.proposeN', {'n': 2, 'points': '+4'}),
        allOf(contains('2'), contains('+4')),
      );
    }
    AppLocale.current.value = Lang.en;
  });
}
