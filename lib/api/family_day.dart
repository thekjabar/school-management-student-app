import 'client.dart';
import 'session.dart';

class FamilyMoment {
  const FamilyMoment({required this.at, required this.place});

  final DateTime? at;
  final String? place;

  static FamilyMoment? fromJson(Object? j) {
    if (j is! Map) return null;
    final at = j['at'] as String?;
    return FamilyMoment(at: at == null ? null : DateTime.tryParse(at)?.toLocal(), place: j['place'] as String?);
  }
}

class FamilyChildDay {
  const FamilyChildDay({
    required this.studentId,
    required this.name,
    required this.school,
    required this.closed,
    required this.noBus,
    required this.note,
    required this.pickup,
    required this.dropoff,
  });

  final String studentId;
  final String name;
  final String? school;
  final bool closed;
  final bool noBus;
  final String? note;
  final FamilyMoment? pickup;
  final FamilyMoment? dropoff;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  factory FamilyChildDay.fromJson(Map<String, dynamic> j) => FamilyChildDay(
        studentId: (j['studentId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        school: j['school'] as String?,
        closed: (j['closed'] ?? false) as bool,
        noBus: (j['noBus'] ?? false) as bool,
        note: j['note'] as String?,
        pickup: FamilyMoment.fromJson(j['pickup']),
        dropoff: FamilyMoment.fromJson(j['dropoff']),
      );
}

enum ClashKind { pickup, dropoff }

class FamilyClash {
  const FamilyClash({required this.kind, required this.first, required this.second, required this.minutesApart});

  final ClashKind kind;
  final FamilyChildDay first;
  final FamilyChildDay second;
  final int minutesApart;
}

const kClashWindowMinutes = 15;

List<FamilyClash> familyClashes(List<FamilyChildDay> children) {
  final out = <FamilyClash>[];
  for (final kind in ClashKind.values) {
    FamilyMoment? of(FamilyChildDay c) => kind == ClashKind.pickup ? c.pickup : c.dropoff;
    for (var i = 0; i < children.length; i++) {
      for (var j = i + 1; j < children.length; j++) {
        final a = of(children[i]);
        final b = of(children[j]);
        if (a?.at == null || b?.at == null) continue;
        final samePlace = a!.place != null && a.place!.trim().toLowerCase() == b!.place?.trim().toLowerCase();
        if (samePlace) continue;
        final apart = a.at!.difference(b!.at!).inMinutes.abs();
        if (apart <= kClashWindowMinutes) {
          out.add(FamilyClash(kind: kind, first: children[i], second: children[j], minutesApart: apart));
        }
      }
    }
  }
  return out;
}

Future<List<FamilyChildDay>> loadFamilyDay(DateTime day) async {
  final api = ApiClient.instance;
  final date = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  final schools = Session.instance.me?.schoolsFor(kGuardianRoles) ?? const [];
  final tenants = schools.isEmpty ? <String?>[null] : [for (final s in schools) s.tenantId];
  final results = await Future.wait(tenants.map((tenantId) async {
    try {
      final json = await api.get('/parent/family-day?date=$date', tenantId: tenantId) as Map<String, dynamic>;
      return ((json['children'] as List?) ?? const [])
          .map((c) => FamilyChildDay.fromJson((c as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const <FamilyChildDay>[];
    }
  }));
  final seen = <String>{};
  return [
    for (final list in results)
      for (final c in list)
        if (seen.add(c.studentId)) c,
  ];
}
