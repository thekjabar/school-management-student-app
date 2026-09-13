import 'package:latlong2/latlong.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import 'run_order.dart';
import 'stop_presence.dart';

const double kApproachNearM = 500;

enum ApproachStage { near, arrived }

class ApproachTarget {
  const ApproachTarget({
    required this.key,
    required this.name,
    required this.children,
    required this.school,
    required this.at,
    required this.arriveWithinM,
  });

  final String key;
  final String name;
  final List<String> children;
  final bool school;
  final LatLng at;
  final double arriveWithinM;
}

class ApproachCue {
  const ApproachCue(this.target, this.stage);

  final ApproachTarget target;
  final ApproachStage stage;
}

String runStopKey(PlannedStop s) => '${s.stopId}|${s.students.firstOrNull?.studentId ?? ''}';

const String kSchoolTargetKey = 'school';

String firedKey(String targetKey, ApproachStage stage) => '$targetKey:${stage.name}';

List<ApproachTarget> approachTargets({
  required List<PlannedStop> stops,
  required String leg,
  SchoolGate? school,
}) {
  final out = <ApproachTarget>[];
  for (final s in stops) {
    if (s.done || !stopIsPlaced(s) || isSchoolStop(s, school?.stopId) || droppedFromRoute(s)) continue;
    final children = [
      for (final r in s.students)
        if (leg == 'RETURN' ? (r.boardedAt != null && r.alightedAt == null) : !r.accountedFor) r.name,
    ];
    if (children.isEmpty) continue;
    out.add(ApproachTarget(
      key: runStopKey(s),
      name: s.name,
      children: children,
      school: false,
      at: LatLng(s.lat!, s.lon!),
      arriveWithinM: reachLimitM(s.radiusM, school: false),
    ));
  }
  if (leg == 'OUT' && school != null && school.placed) {
    out.add(ApproachTarget(
      key: kSchoolTargetKey,
      name: school.name ?? '',
      children: const [],
      school: true,
      at: LatLng(school.lat!, school.lon!),
      arriveWithinM: reachLimitM(school.radiusM, school: true),
    ));
  }
  return out;
}

List<ApproachCue> approachCues({
  required List<ApproachTarget> targets,
  required LatLng bus,
  required double accuracyM,
  required Set<String> fired,
}) {
  final slack = accuracyM.isFinite ? accuracyM.clamp(0.0, kAccuracyCapM) : 0.0;
  final out = <ApproachCue>[];
  for (final target in targets) {
    final gap = metresBetween(bus, target.at) - slack;
    if (gap <= target.arriveWithinM) {
      if (fired.add(firedKey(target.key, ApproachStage.arrived))) {
        fired.add(firedKey(target.key, ApproachStage.near));
        out.add(ApproachCue(target, ApproachStage.arrived));
      }
    } else if (gap <= kApproachNearM) {
      if (fired.add(firedKey(target.key, ApproachStage.near))) {
        out.add(ApproachCue(target, ApproachStage.near));
      }
    }
  }
  return out;
}

String approachPrompt(ApproachCue cue, {required String leg, required Lang lang}) {
  final table = tableFor(lang);
  final key = cue.target.school
      ? (cue.stage == ApproachStage.near ? 'driver.voice.schoolNear' : 'driver.voice.schoolArrived')
      : cue.stage == ApproachStage.arrived
          ? 'driver.voice.arrived'
          : leg == 'RETURN'
              ? 'driver.voice.nearDropOff'
              : 'driver.voice.nearPickUp';
  return (table[key] ?? tableFor(Lang.en)[key] ?? key)
      .replaceAll('{name}', cue.target.name)
      .replaceAll('{children}', cue.target.children.join(', '));
}

Lang? voiceLanguage(Lang app, bool Function(Lang lang) available) {
  if (available(app)) return app;
  if (app == Lang.ckb && available(Lang.ar)) return Lang.ar;
  if (available(Lang.en)) return Lang.en;
  return null;
}

const Map<Lang, List<String>> kVoiceLocales = {
  Lang.en: ['en-US', 'en-GB', 'en'],
  Lang.ar: ['ar-SA', 'ar', 'ar-AE', 'ar-EG', 'ar-IQ'],
  Lang.ckb: ['ckb-IQ', 'ckb', 'ku-IQ', 'ku'],
};
