import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/parent/consent_form_screen.dart';

const _literalKeys = <String>[
  'profile.consents',
  'profile.consentsSub',
  'consent.title',
  'consent.subtitle',
  'consent.awaitingCount',
  'consent.allAnswered',
  'consent.noneAsked',
  'consent.noneAskedFor',
  'consent.waitingHere',
  'consent.version',
  'consent.retention',
  'consent.retentionUnset',
  'consent.expiresOn',
  'consent.sharedWith',
  'consent.scopeNote',
  'consent.readFully',
  'consent.wordingMissing',
  'consent.wordingInOther',
  'consent.agree',
  'consent.refuse',
  'consent.signAndAgree',
  'consent.signTitle',
  'consent.signHere',
  'consent.signLead',
  'consent.useSignature',
  'consent.signatureRequired',
  'consent.signatureFailed',
  'consent.savedNoEcho',
  'consent.agreeConfirmTitle',
  'consent.agreeConfirmBody',
  'consent.refuseConfirmTitle',
  'consent.refuseConfirmBody',
  'consent.savedAgreed',
  'consent.savedRefused',
  'consent.signedOn',
  'consent.answeredOn',
  'consent.withdrawnOn',
  'consent.yourReason',
  'consent.olderWording',
  'consent.byOffice',
  'consent.stopGeneric',
  'consent.withdraw',
  'consent.withdrawTitle',
  'consent.withdrawReason',
  'consent.withdrawReasonHint',
  'consent.withdrawReasonShort',
  'consent.withdrawSend',
  'consent.withdrawDone',
  'common.clear',
  'common.noChildren',
];

ConsentForm _form({
  String purpose = 'PHOTO',
  String? status,
  String? bodyCkb,
  String? bodyAr,
  String? bodyEn,
}) =>
    ConsentForm(
      policyVersionId: 'cmpolicy00000000000000001',
      purpose: purpose,
      key: 'photo',
      version: 3,
      languages: const ['en'],
      awaitingAnswer: status != 'GRANTED' && status != 'REFUSED',
      canWithdraw: status == 'GRANTED',
      signed: false,
      sharedWith: const [],
      status: status,
      bodyCkb: bodyCkb,
      bodyAr: bodyAr,
      bodyEn: bodyEn,
    );

void main() {
  tearDown(() => AppLocale.current.value = Lang.en);

  test('every consent phrase exists in all three languages', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final key in _literalKeys) {
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

  test('every purpose, status and withdrawal warning is words, never a key', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;

      for (final purpose in kConsentPurposes) {
        for (final line in [consentPurposeLabel(purpose), consentStopLine(purpose)]) {
          expect(line, isNot(contains('consent.')), reason: '$purpose in ${lang.code}: $line');
          expect(line, isNot(contains('{')), reason: '$purpose in ${lang.code} left a hole: $line');
          expect(line.trim(), isNotEmpty);
        }
      }

      for (final status in [...kConsentStatuses, null]) {
        final label = consentStatusLook(status).label;
        expect(label, isNot(contains('consent.')), reason: '$status in ${lang.code}: $label');
        expect(label.trim(), isNotEmpty);
      }
    }
  });

  test('a purpose or status the app has never met reads as words, not a key', () {
    AppLocale.current.value = Lang.en;

    expect(consentPurposeLabel('FUTURE_NEW_PURPOSE'), 'Future new purpose');
    expect(consentStopLine('FUTURE_NEW_PURPOSE'), t('consent.stopGeneric'));
    expect(consentStatusLook('SOMETHING_NEW').label, 'Something new');
  });

  test('the answered line names the date, and says nothing when nothing was answered', () {
    AppLocale.current.value = Lang.en;

    expect(consentAnsweredLine(_form()), isNull);

    final signed = ConsentForm(
      policyVersionId: 'cmpolicy00000000000000001',
      purpose: 'PHOTO',
      key: 'photo',
      version: 1,
      languages: const ['en'],
      awaitingAnswer: false,
      canWithdraw: true,
      signed: true,
      sharedWith: const [],
      status: 'GRANTED',
      signedAt: DateTime(2026, 9, 11),
      grantedAt: DateTime(2026, 9, 11),
    );
    expect(consentAnsweredLine(signed), contains('2026'));
    expect(consentAnsweredLine(signed), isNot(contains('consent.')));

    final withdrawn = ConsentForm(
      policyVersionId: 'cmpolicy00000000000000001',
      purpose: 'PHOTO',
      key: 'photo',
      version: 1,
      languages: const ['en'],
      awaitingAnswer: true,
      canWithdraw: false,
      signed: true,
      sharedWith: const [],
      status: 'WITHDRAWN',
      signedAt: DateTime(2026, 9, 1),
      withdrawnAt: DateTime(2026, 9, 10),
    );
    expect(
      consentAnsweredLine(withdrawn),
      contains('10'),
      reason: 'a withdrawn form must show when it was withdrawn, not when it was signed',
    );
  });

  test('a form with no wording at all offers nothing to sign', () {
    AppLocale.current.value = Lang.ckb;
    expect(_form().wording, isNull);
  });

  test('wording falls back to a language the school did publish, and says which', () {
    AppLocale.current.value = Lang.ckb;

    final onlyEnglish = _form(bodyEn: 'The school may photograph your child.');
    expect(onlyEnglish.wording?.language, 'en');
    expect(onlyEnglish.wording?.rightToLeft, isFalse);
    expect(
      tv('consent.wordingInOther', {'lang': t('consent.lang.en')}),
      isNot(contains('{')),
    );

    final sorani = _form(bodyCkb: 'قوتابخانە دەتوانێت وێنەی منداڵەکەت بگرێت.', bodyEn: 'English');
    expect(sorani.wording?.language, 'ckb');
    expect(sorani.wording?.rightToLeft, isTrue);

    AppLocale.current.value = Lang.ar;
    final arabic = _form(bodyAr: 'يجوز للمدرسة تصوير طفلك.', bodyEn: 'English');
    expect(arabic.wording?.language, 'ar');
    expect(arabic.wording?.rightToLeft, isTrue);
  });

  test('every body language the server can send has a name in every app language', () {
    for (final lang in Lang.values) {
      AppLocale.current.value = lang;
      for (final code in kConsentBodyLanguages) {
        final name = t('consent.lang.$code');
        expect(name, isNot(contains('consent.')), reason: '$code in ${lang.code}: $name');
        expect(name.trim(), isNotEmpty);
      }
    }
  });
}
