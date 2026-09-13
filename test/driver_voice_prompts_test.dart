import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:student_app/api/crew_api.dart';
import 'package:student_app/i18n/strings.dart';
import 'package:student_app/screens/driver/approach_prompts.dart';

RiderOnStop _rider(String id, String name, {DateTime? boardedAt, DateTime? alightedAt, String? resolution}) =>
    RiderOnStop(
      studentId: id,
      name: name,
      pickup: null,
      seatNumber: null,
      requiresAssistance: false,
      boardedAt: boardedAt,
      alightedAt: alightedAt,
      resolution: resolution,
    );

PlannedStop _stop(String id, String name, List<RiderOnStop> students, {DateTime? departedAt, int? radiusM}) =>
    PlannedStop(
      stopId: id,
      name: name,
      landmark: null,
      lat: 36.2,
      lon: 44.0,
      plannedSequence: 1,
      metresAway: null,
      students: students,
      arrivedAt: departedAt,
      departedAt: departedAt,
      skipped: false,
      etaAt: null,
      etaIsActual: false,
      dwellSeconds: 55,
      driveSeconds: 0,
      radiusM: radiusM,
    );

LatLng _north(double metres) => LatLng(36.2 + metres / 111195, 44.0);

void main() {
  final earlier = DateTime(2026, 9, 14, 7);
  const gate = SchoolGate(stopId: 'ckgate', name: 'Sunrise', lat: 36.25, lon: 44.05, sequence: 5);

  test('500 m warns once, the arrival radius arrives once, and nothing repeats', () {
    final targets = approachTargets(
      stops: [_stop('cks1', 'Lana Azad', [_rider('ckl', 'Lana Azad')])],
      leg: 'OUT',
    );
    final fired = <String>{};

    expect(approachCues(targets: targets, bus: _north(900), accuracyM: 5, fired: fired), isEmpty);

    final near = approachCues(targets: targets, bus: _north(480), accuracyM: 5, fired: fired);
    expect(near.map((c) => c.stage), [ApproachStage.near]);
    expect(approachCues(targets: targets, bus: _north(300), accuracyM: 5, fired: fired), isEmpty);

    final arrived = approachCues(targets: targets, bus: _north(90), accuracyM: 5, fired: fired);
    expect(arrived.map((c) => c.stage), [ApproachStage.arrived]);
    expect(approachCues(targets: targets, bus: _north(10), accuracyM: 5, fired: fired), isEmpty);
    expect(approachCues(targets: targets, bus: _north(450), accuracyM: 5, fired: fired), isEmpty);
  });

  test('jumping straight inside the radius says only the arrival, and a restored set stays quiet', () {
    final targets = approachTargets(
      stops: [_stop('cks1', 'Lana Azad', [_rider('ckl', 'Lana Azad')], radiusM: 140)],
      leg: 'OUT',
    );
    final fired = <String>{};
    final cues = approachCues(targets: targets, bus: _north(130), accuracyM: 5, fired: fired);
    expect(cues.map((c) => c.stage), [ApproachStage.arrived]);

    final restored = fired.toSet();
    expect(approachCues(targets: targets, bus: _north(400), accuracyM: 5, fired: restored), isEmpty);
    expect(approachCues(targets: targets, bus: _north(20), accuracyM: 5, fired: restored), isEmpty);
  });

  test('targets are the stops with work left, and the school on the way in only', () {
    final stops = [
      _stop('cks1', 'Done', [_rider('cka', 'A', boardedAt: earlier)], departedAt: earlier),
      _stop('cks2', 'Waiting', [_rider('ckb', 'Bea')]),
      _stop('cks3', 'Not riding', [_rider('ckc', 'C', resolution: 'NO_SHOW')]),
      _stop('cks4', 'Aboard', [_rider('ckd', 'Dara', boardedAt: earlier)]),
    ];
    final out = approachTargets(stops: stops, leg: 'OUT', school: gate);
    expect(out.map((t) => t.name), ['Waiting', 'Sunrise']);
    expect(out.last.school, isTrue);
    expect(out.last.arriveWithinM, 150);

    final home = approachTargets(stops: stops, leg: 'RETURN', school: gate);
    expect(home.map((t) => t.name), ['Aboard']);
    expect(home.single.children, ['Dara']);
  });

  test('the wording follows the leg and the language', () {
    const stop = ApproachTarget(
      key: 'cks2|ckb',
      name: 'Bea Karim',
      children: ['Bea Karim'],
      school: false,
      at: LatLng(36.2, 44.0),
      arriveWithinM: 100,
    );
    const school = ApproachTarget(
      key: kSchoolTargetKey,
      name: 'Sunrise',
      children: [],
      school: true,
      at: LatLng(36.25, 44.05),
      arriveWithinM: 150,
    );
    expect(
      approachPrompt(const ApproachCue(stop, ApproachStage.near), leg: 'OUT', lang: Lang.en),
      'In 500 metres, Bea Karim. Get ready to pick up Bea Karim.',
    );
    expect(
      approachPrompt(const ApproachCue(stop, ApproachStage.near), leg: 'RETURN', lang: Lang.en),
      'In 500 metres, Bea Karim. Get ready to drop off Bea Karim.',
    );
    expect(
      approachPrompt(const ApproachCue(stop, ApproachStage.arrived), leg: 'OUT', lang: Lang.en),
      'You have arrived at Bea Karim’s stop.',
    );
    expect(approachPrompt(const ApproachCue(school, ApproachStage.arrived), leg: 'OUT', lang: Lang.en),
        'You have arrived at school.');
    final kurdish = approachPrompt(const ApproachCue(stop, ApproachStage.near), leg: 'OUT', lang: Lang.ckb);
    expect(kurdish, contains('Bea Karim'));
    expect(kurdish, isNot(contains('{')));
    final arabic = approachPrompt(const ApproachCue(school, ApproachStage.near), leg: 'OUT', lang: Lang.ar);
    expect(arabic, tableFor(Lang.ar)['driver.voice.schoolNear']);
  });

  test('Kurdish falls back to an Arabic voice, then English; others fall back to English', () {
    bool only(Set<Lang> have, Lang l) => have.contains(l);
    expect(voiceLanguage(Lang.ckb, (l) => only({Lang.ckb, Lang.ar, Lang.en}, l)), Lang.ckb);
    expect(voiceLanguage(Lang.ckb, (l) => only({Lang.ar, Lang.en}, l)), Lang.ar);
    expect(voiceLanguage(Lang.ckb, (l) => only({Lang.en}, l)), Lang.en);
    expect(voiceLanguage(Lang.ar, (l) => only({Lang.ar, Lang.en}, l)), Lang.ar);
    expect(voiceLanguage(Lang.ar, (l) => only({Lang.en}, l)), Lang.en);
    expect(voiceLanguage(Lang.en, (l) => only({}, l)), isNull);
  });
}
