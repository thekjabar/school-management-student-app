import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';

Map<String, dynamic> _event({
  bool replyWanted = true,
  bool replyClosed = false,
  bool canReply = true,
  bool cancelled = false,
  Map<String, dynamic>? myReply,
}) =>
    {
      'id': 'cmtzn8ufo00000nny6zw28vnr',
      'title': 'Sports day',
      'titleNames': {'ckb': 'ڕۆژی وەرزش', 'ar': 'يوم الرياضة', 'en': 'Sports day'},
      'description': null,
      'descriptionNames': null,
      'place': 'The big yard',
      'placeNames': {'ckb': 'حەوشە گەورەکە'},
      'startsAt': '2026-10-04T07:30:00.000Z',
      'endsAt': '2026-10-04T10:00:00.000Z',
      'day': '2026-10-04',
      'cancelled': cancelled,
      'replyWanted': replyWanted,
      'replyClosesAt': '2026-10-01T20:59:00.000Z',
      'replyClosed': replyClosed,
      'canReply': canReply,
      'headcountWanted': true,
      'headcountMax': 4,
      'myReply': myReply,
    };

Map<String, dynamic> _balance({
  int balanceIqd = 12000,
  int? dailyLimitIqd,
  bool low = false,
}) =>
    {
      'balanceIqd': balanceIqd,
      'dailyLimitIqd': dailyLimitIqd,
      'dailyLimitIsMine': dailyLimitIqd != null,
      'low': low,
      'lowBalanceIqd': 5000,
      'updatedAt': '2026-09-22T06:00:00.000Z',
      'today': '2026-09-22',
      'lastDayYouCanOrder': '2026-09-29',
      'cutoffHour': 8,
      'cutoffMinute': 30,
    };

void main() {
  test('an event waits for an answer only while the school can still take one', () {
    expect(SchoolEventItem.fromJson(_event()).awaitingReply, isTrue);

    final answered = SchoolEventItem.fromJson(_event(myReply: {
      'reply': EventReplyKind.yes,
      'headcount': 2,
      'note': ' see you there ',
      'repliedAt': '2026-09-20T09:00:00.000Z',
    }));
    expect(answered.awaitingReply, isFalse);
    expect(answered.myReply!.headcount, 2);
    expect(answered.myReply!.note, 'see you there');
  });

  test('a closed or called-off event never asks the family for an answer', () {
    final closed = SchoolEventItem.fromJson(_event(replyClosed: true, canReply: false));
    expect(closed.awaitingReply, isFalse);
    expect(closed.replyClosed, isTrue);

    final off = SchoolEventItem.fromJson(_event(cancelled: true, canReply: false));
    expect(off.awaitingReply, isFalse);
    expect(off.cancelled, isTrue);
  });

  test('an event that wants no answer is never counted as waiting', () {
    final notice = SchoolEventItem.fromJson(_event(replyWanted: false, canReply: false));
    expect(notice.awaitingReply, isFalse);
  });

  test('an event speaks the language the family reads, and falls back to the plain name', () {
    final event = SchoolEventItem.fromJson(_event());

    AppLocale.current.value = Lang.ckb;
    expect(event.titleText, 'ڕۆژی وەرزش');
    expect(event.placeText, 'حەوشە گەورەکە');

    AppLocale.current.value = Lang.ar;
    expect(event.titleText, 'يوم الرياضة');
    expect(event.placeText, 'The big yard');

    AppLocale.current.value = Lang.en;
    expect(event.titleText, 'Sports day');
    expect(event.descriptionText, isEmpty);
  });

  test('the day an event sits on is the school\'s day, not the phone\'s clock', () {
    final event = SchoolEventItem.fromJson(_event());
    expect(event.day, DateTime(2026, 10, 4));
    expect(dayKeyOf(event.day), '2026-10-04');
    expect(dayKeyOf(DateTime(2026, 1, 2)), '2026-01-02');
  });

  test('a balance knows the days it may be spent on and when the day shuts', () {
    final balance = CanteenBalance.fromJson(_balance(dailyLimitIqd: 4000, low: true));
    expect(balance.firstDay, DateTime(2026, 9, 22));
    expect(balance.lastDay, DateTime(2026, 9, 29));
    expect(balance.cutoffMinuteOfDay, 8 * 60 + 30);
    expect(balance.low, isTrue);
    expect(balance.dailyLimitIsMine, isTrue);
  });

  test('a balance with no limit of the family\'s own carries none', () {
    final balance = CanteenBalance.fromJson(_balance());
    expect(balance.dailyLimitIqd, isNull);
    expect(balance.dailyLimitIsMine, isFalse);
  });

  test('an order can only be changed while it is live and the cut-off is ahead', () {
    Map<String, dynamic> order(String status, DateTime cutoff) => {
          'id': 'cmtzn8ufo00010nny6zw28vnr',
          'day': '2026-09-23',
          'status': status,
          'totalIqd': 3500,
          'cutoffAt': cutoff.toUtc().toIso8601String(),
          'allergyWarned': false,
          'collectedAt': null,
          'placedAt': '2026-09-22T05:00:00.000Z',
          'lines': [
            {
              'itemId': 'cmtzn8ufo00020nny6zw28vnr',
              'name': 'Cheese sandwich',
              'quantity': 2,
              'unitPriceIqd': 1750,
              'lineTotalIqd': 3500,
            },
          ],
          'balanceIqd': 8500,
        };

    final ahead = DateTime.now().add(const Duration(hours: 2));
    final behind = DateTime.now().subtract(const Duration(hours: 2));

    final open = CanteenOrder.fromJson(order(CanteenOrderState.placed, ahead));
    expect(open.live, isTrue);
    expect(open.changeable, isTrue);
    expect(open.date, DateTime(2026, 9, 23));
    expect(open.lines.single.lineTotalIqd, open.lines.single.quantity * open.lines.single.unitPriceIqd);

    expect(CanteenOrder.fromJson(order(CanteenOrderState.placed, behind)).changeable, isFalse);
    expect(CanteenOrder.fromJson(order(CanteenOrderState.collected, ahead)).changeable, isFalse);
    expect(CanteenOrder.fromJson(order(CanteenOrderState.cancelled, ahead)).live, isFalse);
  });

  test('an item is only flagged for allergy when the school warned about this child', () {
    Map<String, dynamic> item(List<String> warnings) => {
          'id': 'cmtzn8ufo00030nny6zw28vnr',
          'name': 'Peanut biscuits',
          'names': {'ckb': 'بسکویتی فستق'},
          'description': null,
          'descriptionNames': null,
          'priceIqd': 1000,
          'allergens': ['PEANUTS', 'WHEAT_GLUTEN'],
          'allergyWarnings': warnings,
        };

    expect(CanteenMenuItem.fromJson(item(const [])).clashesWithAllergy, isFalse);
    final risky = CanteenMenuItem.fromJson(item(const ['PEANUTS']));
    expect(risky.clashesWithAllergy, isTrue);
    expect(risky.allergyWarnings, ['PEANUTS']);
    expect(risky.allergens, ['PEANUTS', 'WHEAT_GLUTEN']);
  });

  test('a ledger row says plainly whether money came in or went out', () {
    CanteenLedgerRow row(String kind, int amount) => CanteenLedgerRow.fromJson({
          'id': 'cmtzn8ufo00040nny6zw28vnr',
          'kind': kind,
          'amountIqd': amount,
          'balanceAfterIqd': 9000,
          'reason': null,
          'day': '2026-09-22',
          'at': '2026-09-22T05:30:00.000Z',
        });

    expect(row(CanteenLedgerKind.topUp, 10000).addsMoney, isTrue);
    expect(row(CanteenLedgerKind.order, -1500).addsMoney, isFalse);
    expect(row(CanteenLedgerKind.orderRefund, 1500).addsMoney, isTrue);
    expect(row(CanteenLedgerKind.topUpReversal, -10000).addsMoney, isFalse);
  });

  test('every allergen the school can record has a word in all three languages', () {
    const allergens = [
      'PEANUTS',
      'TREE_NUTS',
      'MILK',
      'EGGS',
      'WHEAT_GLUTEN',
      'SESAME',
      'SOY',
      'FISH',
      'SHELLFISH',
      'HONEY',
    ];
    for (final lang in Lang.values) {
      for (final a in allergens) {
        expect(
          tableFor(lang)['allergen.$a'],
          isNotNull,
          reason: '$a has no word in ${lang.code}',
        );
      }
    }
  });

  test('events and the canteen are package sections the school can switch off', () {
    final ent = PackageEntitlements.fromJson({
      'sections': [
        {'key': ParentSection.events, 'paid': true},
        {'key': ParentSection.canteen, 'paid': true},
      ],
      'children': [
        {'studentId': 'paying', 'lockedSections': <String>[]},
        {'studentId': 'lapsed', 'lockedSections': [ParentSection.events, ParentSection.canteen]},
      ],
    });

    expect(ent.access('paying', ParentSection.events), SectionAccess.open);
    expect(ent.access('paying', ParentSection.canteen), SectionAccess.open);
    expect(ent.access('lapsed', ParentSection.events), SectionAccess.locked);
    expect(ent.access('lapsed', ParentSection.canteen), SectionAccess.locked);
    expect(PackageEntitlements.none.access('paying', ParentSection.canteen), SectionAccess.unknown);
  });
}
