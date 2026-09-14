import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_app/api/client.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/session.dart';
import 'package:student_app/i18n/strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  setUpAll(() async {
    await Session.instance.signIn('07501190001', 'School@123');
  });

  for (final lang in Lang.values) {
    test('the package overview and school fees parse in ${lang.code}', () async {
      AppLocale.current.value = lang;
      final package = await ParentApi.instance.packageOverview();
      expect(package.methods, containsAll(['CASH', 'BANK_TRANSFER', 'FIB', 'FASTPAY', 'ZAINCASH', 'ASIAHAWALA', 'OTHER']));
      expect(package.children, isNotEmpty, reason: 'this guardian has no child on the package overview');
      for (final c in package.children) {
        expect(c.studentId, isNotEmpty);
        expect(c.schoolId, isNotEmpty);
        expect(c.childName, isNotEmpty);
        expect(c.school, isNotEmpty);
        stdout.writeln('${lang.code} package ${c.childName} @ ${c.school}: ${c.status} ${c.since} ${c.until} waiting ${c.pendingNotices.length}');
      }

      final fees = await ParentApi.instance.schoolFees();
      expect(fees.children, isNotEmpty);
      for (final c in fees.children) {
        final s = c.statement;
        stdout.writeln(
          '${lang.code} fees ${c.childName} @ ${c.school}: allowed ${c.allowsAppPayment} year ${c.year?.name} '
          'due ${s?.dueIqd} paid ${s?.paidIqd} pending ${s?.pendingIqd} balance ${s?.balanceIqd} overdue ${s?.overdueIqd} '
          'next ${s?.nextDueOn} ${s?.nextDueIqd} instalments ${s?.instalments.map((i) => '${i.dueOn}:${i.payableIqd}:${i.state.name}').join(',')}',
        );
        if (c.allowsAppPayment) {
          expect(c.code, isNull);
          if (c.year != null) {
            expect(s, isNotNull);
            expect(s!.balanceIqd, s.dueIqd - s.paidIqd);
            expect(s.instalments.fold<int>(0, (sum, i) => sum + i.payableIqd), s.dueIqd);
          }
        } else {
          expect(c.code, SchoolFeesCode.notInApp);
          expect(c.notInAppText(), isNotEmpty);
        }
      }
    });
  }

  for (final payee in PaymentPayee.values) {
    test('a ${payee.name} notice is sent, read back, listed, withdrawn, and a second withdrawal is harmless', () async {
      AppLocale.current.value = Lang.en;
      final String studentId;
      final String schoolId;
      if (payee == PaymentPayee.ksp) {
        final child = (await ParentApi.instance.packageOverview()).children.first;
        studentId = child.studentId;
        schoolId = child.schoolId;
      } else {
        final allowed = (await ParentApi.instance.schoolFees()).children.where((c) => c.allowsAppPayment && c.year != null);
        if (allowed.isEmpty) {
          markTestSkipped('no school of this guardian takes fees through the app');
          return;
        }
        studentId = allowed.first.studentId;
        schoolId = allowed.first.schoolId;
      }

      final key = 'live-check-${DateTime.now().microsecondsSinceEpoch}';
      final sent = await ParentApi.instance.submitPaymentNotice(
        payee,
        studentId: studentId,
        schoolId: schoolId,
        amountIqd: 250,
        method: 'OTHER',
        idempotencyKey: key,
        paidOn: DateTime.now(),
        reference: 'LIVE-CHECK',
        notes: 'Automated check from the app test. Safe to ignore.',
      );
      final notice = sent.notice!;
      try {
        stdout.writeln('${payee.name} sent: replayed ${sent.replayed} "${sent.text('')}" ${notice.id} ${notice.status} ${notice.paidOn}');
        expect(sent.replayed, isFalse);
        expect(notice.pending, isTrue);
        expect(notice.payee, payee);
        expect(notice.amountIqd, 250);
        expect(notice.reference, 'LIVE-CHECK');
        expect(notice.sentByMe, isTrue);
        expect(sent.messages.ckb, isNotNull);
        expect(sent.messages.ar, isNotNull);
        expect(sent.messages.en, isNotNull);

        final replay = await ParentApi.instance.submitPaymentNotice(
          payee,
          studentId: studentId,
          schoolId: schoolId,
          amountIqd: 250,
          method: 'OTHER',
          idempotencyKey: key,
        );
        expect(replay.replayed, isTrue);
        expect(replay.notice!.id, notice.id);

        final read = await ParentApi.instance.paymentNotice(payee, notice.id);
        expect(read.id, notice.id);
        final listed = await ParentApi.instance.paymentNotices(payee, studentId: studentId, limit: 5);
        expect(listed.rows.map((n) => n.id), contains(notice.id));
      } finally {
        await ParentApi.instance.withdrawPaymentNotice(payee, notice);
      }
      final after = await ParentApi.instance.paymentNotice(payee, notice.id);
      expect(after.withdrawn, isTrue);
      expect(after.withdrawnAt, isNotNull);
      await ParentApi.instance.withdrawPaymentNotice(payee, after);

      await expectLater(
        ParentApi.instance.submitPaymentNotice(
          payee,
          studentId: studentId,
          schoolId: schoolId,
          amountIqd: 100,
          method: 'OTHER',
          idempotencyKey: '$key-small',
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
    });
  }
}
