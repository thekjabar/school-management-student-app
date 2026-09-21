import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/api/parent_api.dart';
import 'package:student_app/api/teacher_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/ui/translated_body.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUp(() => AppLocale.current.value = Lang.en);

  test('a news post keeps its photos, its date and the campus that wrote it', () {
    final post = NewsPost.fromJson({
      'id': 'cmnewspost0000000000000001',
      'text': 'ڕۆژی خوێندنەوە',
      'textEn': 'Reading day',
      'publishedAt': '2026-09-18T09:30:00.000Z',
      'campusNames': {'ckb': 'بنەڕەتی', 'en': 'Primary campus'},
      'photos': [
        {
          'id': 'cmnewsphoto000000000000001',
          'url': 'https://cdn.example/full.jpg',
          'thumbnailUrl': 'https://cdn.example/thumb.jpg',
          'width': 1600,
          'height': 900,
        },
        {'id': 'cmnewsphoto000000000000002', 'url': 'https://cdn.example/two.jpg'},
      ],
    });

    expect(post.text, 'Reading day');
    expect(post.campusName, 'Primary campus');
    expect(post.publishedAt?.toUtc().day, 18);
    expect(post.photos.length, 2);
    expect(post.photos.first.aspect, closeTo(16 / 9, 0.001));
    expect(post.photos.last.thumbnailUrl, 'https://cdn.example/two.jpg');
    expect(post.photos.last.aspect, 1);
  });

  test('a photo a family withheld consent for is reported, and one nobody is named in is not ready', () {
    final post = TeacherNewsPost.fromJson({
      'id': 'cmnewspost0000000000000002',
      'text': 'Sports day',
      'classIds': ['cmclass00000000000000001'],
      'published': false,
      'photos': [
        {
          'id': 'cmnewsphoto000000000000003',
          'url': 'https://cdn.example/a.jpg',
          'noChildren': false,
          'withheldForConsent': true,
          'tags': [
            {'studentId': 'cmstudent00000000000001', 'name': 'Ava'},
          ],
        },
        {
          'id': 'cmnewsphoto000000000000004',
          'url': 'https://cdn.example/b.jpg',
          'noChildren': false,
          'withheldForConsent': false,
          'tags': const [],
        },
        {
          'id': 'cmnewsphoto000000000000005',
          'url': 'https://cdn.example/c.jpg',
          'noChildren': true,
          'tags': const [],
        },
      ],
    });

    expect(post.photos[0].named, isTrue);
    expect(post.photos[0].withheldForConsent, isTrue);
    expect(post.photos[0].taggedIds, ['cmstudent00000000000001']);
    expect(post.photos[1].named, isFalse);
    expect(post.photos[2].named, isTrue);
  });

  test('a child with no photo consent is carried through so the teacher is warned', () {
    final child = TeacherNewsChild.fromJson({
      'id': 'cmstudent00000000000002',
      'code': 'S-2',
      'name': 'ئاڤا',
      'names': {'ckb': 'ئاڤا', 'en': 'Ava'},
      'photoConsent': false,
    });

    expect(child.photoConsent, isFalse);
    expect(child.name, 'Ava');
    AppLocale.current.value = Lang.ckb;
    expect(child.name, 'ئاڤا');
  });

  testWidgets('a message from the school reads in the family\'s language, and the original is one tap away',
      (tester) async {
    await tester.pumpWidget(_wrap(const TranslatedBody(
      body: 'سبەینێ سەفەرێکی خوێندن هەیە',
      translated: 'There is a school trip tomorrow',
      tint: Colors.teal,
    )));

    expect(find.text('There is a school trip tomorrow'), findsOneWidget);
    expect(find.text('سبەینێ سەفەرێکی خوێندن هەیە'), findsNothing);

    await tester.tap(find.text(t('conv.translated')));
    await tester.pump();

    expect(find.text('سبەینێ سەفەرێکی خوێندن هەیە'), findsOneWidget);
    expect(find.text('There is a school trip tomorrow'), findsNothing);
    expect(find.text(t('conv.showTranslation')), findsOneWidget);
  });

  testWidgets('a message that was not translated shows no toggle at all', (tester) async {
    await tester.pumpWidget(_wrap(const TranslatedBody(
      body: 'Thank you',
      translated: null,
      tint: Colors.teal,
    )));

    expect(find.text('Thank you'), findsOneWidget);
    expect(find.text(t('conv.translated')), findsNothing);

    await tester.pumpWidget(_wrap(const TranslatedBody(
      body: 'Thank you',
      translated: 'Thank you',
      tint: Colors.teal,
    )));

    expect(find.text(t('conv.translated')), findsNothing);
  });

  test('a reply the server translated is carried on the message', () {
    final message = ThreadMessage.fromJson({
      'id': 'cmmessage000000000000001',
      'body': 'سوپاس',
      'translatedBody': 'Thank you',
      'fromSchool': true,
      'sentAt': '2026-09-18T10:00:00.000Z',
    });

    expect(message.body, 'سوپاس');
    expect(message.translatedBody, 'Thank you');
  });
}
