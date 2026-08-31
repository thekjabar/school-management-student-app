import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// What the school has written down about one child.
///
/// This screen exists because the answer used to be a telephone call to the
/// office. A parent who wants to check the spelling on a certificate, or which
/// room their daughter is in, or whether the school still has last year's
/// emergency number, should not have to ring anybody.
///
/// It shows only facts the record actually holds. Nothing here is computed,
/// scored or inferred — a field the school never filled in is simply absent,
/// which is itself worth knowing.
class StudentInfoScreen extends StatelessWidget {
  const StudentInfoScreen({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('info.title')),
            Expanded(
              child: Loader<ChildProfile>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: () => ParentApi.instance.profile(child.studentId),
                builder: (context, p) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IdentityCard(profile: p, tint: tint),
                    const SizedBox(height: kCardGap),

                    // Each row carries its own mark. Seven labels in a column
                    // are seven identical greys to scan; seven marks are seven
                    // different shapes, and the eye finds "Room" without
                    // reading the other six.
                    _Section(
                      title: t('info.atSchool'),
                      icon: Icons.school_outlined,
                      color: tint,
                      rows: [
                        _Row(Icons.class_outlined, t('info.class'), p.className),
                        _Row(
                          Icons.stairs_outlined,
                          t('info.grade'),
                          p.gradeLabel ?? _grade(p.gradeLevel),
                        ),
                        _Row(Icons.grid_view_rounded, t('info.section'), p.section),
                        _Row(Icons.meeting_room_outlined, t('info.room'), p.room),
                        _Row(Icons.schedule_rounded, t('info.shift'), humanise(p.shift)),
                        _Row(
                          Icons.person_outline_rounded,
                          t('info.teacher'),
                          p.homeroomTeacher,
                        ),
                        _Row(
                          Icons.format_list_numbered_rounded,
                          t('info.rollNo'),
                          p.rollNo,
                        ),
                      ],
                    ),
                    const SizedBox(height: kCardGap),

                    _Section(
                      title: t('info.enrolment'),
                      icon: Icons.badge_outlined,
                      color: AppTheme.blue,
                      rows: [
                        _Row(Icons.tag_rounded, t('info.studentNo'), p.code),
                        _Row(
                          Icons.calendar_today_outlined,
                          t('info.year'),
                          p.academicYear,
                        ),
                        _Row(
                          Icons.location_city_outlined,
                          t('info.campus'),
                          p.campusName,
                        ),
                        _Row(Icons.place_outlined, t('info.address'), p.campusAddress),
                        _Row(
                          Icons.event_available_outlined,
                          t('info.since'),
                          longDate(p.enrolledAt),
                        ),
                      ],
                    ),

                    if (p.guardians.isNotEmpty) ...[
                      const SizedBox(height: kCardGap),
                      _Guardians(guardians: p.guardians, tint: tint),
                    ],

                    if (p.medical != null && !p.medical!.isEmpty) ...[
                      const SizedBox(height: kCardGap),
                      _Medical(medical: p.medical!),
                    ],

                    if (p.support != null && !p.support!.isEmpty) ...[
                      const SizedBox(height: kCardGap),
                      _Support(support: p.support!),
                    ],

                    const SizedBox(height: 12),
                    // The office keeps the record; the app only reads it. Say
                    // so, so that a parent who spots a wrong birth date knows
                    // where to take it instead of hunting for an edit button
                    // that will never be there.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        t('info.correctionNote'),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _grade(int? level) => level == null ? null : tv('grade.n', {'n': '$level'});
}

/* ---------------------------------------------------------------------------
 * Who they are
 * ------------------------------------------------------------------------- */

/// The face, the name, and the two things everyone asks for first.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.tint});

  final ChildProfile profile;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = profile;

    // Born, Gender and Nationality — whichever of the three the record holds.
    // Built as a list rather than as three `if`s in a Row so the hairline
    // rules fall BETWEEN whatever survives, instead of leaving a rule standing
    // against an empty column.
    final facts = <_FactData>[
      if (p.dob != null)
        _FactData(
          icon: Icons.cake_outlined,
          label: t('info.born'),
          value: shortDate(p.dob),
          // The age is the part a parent reads; the date is the part they
          // check.
          caption: p.ageYears == null
              ? null
              : tv('info.yearsOld', {'n': '${p.ageYears}'}),
        ),
      if (p.gender != null)
        _FactData(
          icon: Icons.wc_rounded,
          label: t('info.gender'),
          value: humanise(p.gender),
        ),
      if (p.nationality != null)
        _FactData(
          icon: Icons.flag_outlined,
          label: t('info.nationality'),
          value: p.nationality!,
        ),
    ];

    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: Stack(
          children: [
            // The school, at the end of the card, as a wash rather than as a
            // picture. The illustration is twice as wide as it is tall, so at
            // any size where it reads as a drawing it eats the width the
            // child's full name needs — and the name is the one thing on this
            // card that cannot afford to wrap to three lines. Behind and
            // faint, it still does the job it was there to do.
            PositionedDirectional(
              end: -18,
              bottom: -16,
              child: Opacity(
                opacity: AppTheme.dark ? 0.10 : 0.16,
                child: Image.asset('assets/art/school_shield.png', width: 156),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Avatar(url: p.photoUrl, name: p.name, tint: tint),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            // The full enrolled name, because the reason to
                            // look is usually to check a spelling against a
                            // document.
                            Text(
                              p.fullName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.2,
                                color: AppTheme.text,
                              ),
                            ),
                            if (p.nickname != null && p.nickname!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                tv('info.knownAs', {'name': p.nickname!}),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 9),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (p.className != null)
                                  _MarkChip(
                                    icon: Icons.school_rounded,
                                    label: p.className!,
                                    color: tint,
                                  ),
                                _MarkChip(
                                  icon: Icons.badge_outlined,
                                  label: '#${p.code}',
                                  color: AppTheme.blue,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: AppTheme.border),
                    const SizedBox(height: 13),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < facts.length; i++) ...[
                            if (i > 0)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 10,
                                  end: 12,
                                ),
                                child: Container(width: 1, color: AppTheme.border),
                              ),
                            Expanded(child: _Fact(fact: facts[i], tint: tint)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.tint});

  final String? url;
  final String name;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;

    // No photograph is the norm rather than the exception here: plenty of
    // families do not consent to one, and the record honours that. Initials
    // are not a placeholder for a missing image, they are the answer.
    Widget fallback() => Center(
          child: Text(
            _initials(name),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: tint,
            ),
          ),
        );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.11),
        borderRadius: BorderRadius.circular(26),
      ),
      child: url == null || url!.isEmpty
          ? fallback()
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.first;
    return parts.first.characters.first + parts[1].characters.first;
  }
}

/// A tinted pill with a mark in it — the class and the student code.
class _MarkChip extends StatelessWidget {
  const _MarkChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactData {
  const _FactData({
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
}

class _Fact extends StatelessWidget {
  const _Fact({required this.fact, required this.tint});

  final _FactData fact;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(fact.icon, size: 13, color: tint),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                fact.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          fact.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
            color: AppTheme.text,
          ),
        ),
        if (fact.caption != null)
          Text(
            fact.caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
      ],
    );
  }
}

/* ---------------------------------------------------------------------------
 * The record
 * ------------------------------------------------------------------------- */

/// A mark, a label and a value. Null values are dropped by [_Section].
class _Row {
  const _Row(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String? value;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    // A field the school never filled in is not shown as an empty row. An
    // interface full of dashes reads as broken; a shorter card reads as
    // "that is everything we have", which is the truth.
    final shown = rows.where((r) => r.value != null && r.value!.trim().isNotEmpty).toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, color: color, title: title),
          const SizedBox(height: 12),
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    // Nudged onto the text's baseline rather than its box.
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(shown[i].icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    shown[i].label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      shown[i].value!,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.2,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.color, required this.title});

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: AppTheme.dark ? 0.22 : 0.11),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
              color: AppTheme.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _Guardians extends StatelessWidget {
  const _Guardians({required this.guardians, required this.tint});

  final List<GuardianOnAccount> guardians;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.people_alt_outlined,
            color: AppTheme.green,
            title: t('info.guardians'),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < guardians.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 11),
              child: Row(
                children: [
                  Icon(
                    guardians[i].isYou
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    size: 16,
                    color: AppTheme.green,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guardians[i].isYou
                              ? tv('info.you', {'name': guardians[i].name})
                              : guardians[i].name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.3,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          humanise(guardians[i].relationship),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Who the office rings first. Worth being explicit about,
                  // because families frequently believe it is the other parent.
                  if (guardians[i].isPrimary) ...[
                    const SizedBox(width: 10),
                    StatusChip(t('info.mainContact'), color: tint),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Medical extends StatelessWidget {
  const _Medical({required this.medical});

  final MedicalSummary medical;

  @override
  Widget build(BuildContext context) {
    final m = medical;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.medical_services_outlined,
            color: AppTheme.rose,
            title: t('info.medical'),
          ),
          if (m.flags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in m.flags) StatusChip(humanise(f), color: AppTheme.rose),
              ],
            ),
          ],
          if (m.actionText != null && m.actionText!.isNotEmpty) ...[
            const SizedBox(height: 11),
            Text(
              m.actionText!,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
              ),
            ),
          ],
          if (m.carriesMedication)
            _Line(
              icon: Icons.medication_outlined,
              color: AppTheme.rose,
              text: m.medicationLocation == null || m.medicationLocation!.isEmpty
                  ? t('info.carriesMedication')
                  : tv('info.carriesMedicationAt', {'where': m.medicationLocation!}),
            ),
          if (m.emergencyContacts.isNotEmpty)
            _Line(
              icon: Icons.phone_in_talk_outlined,
              color: AppTheme.rose,
              text: tv('info.ringInOrder', {'names': m.emergencyContacts.join(' → ')}),
            ),
          if (m.needsReview) ...[
            const SizedBox(height: 12),
            // Stale medical information is more dangerous than none, because
            // everyone assumes it is current.
            NoticeBanner(
              icon: Icons.update_rounded,
              title: t('info.medicalStale'),
              body: t('info.medicalStaleBody'),
              color: AppTheme.amber,
            ),
          ],
        ],
      ),
    );
  }
}

class _Support extends StatelessWidget {
  const _Support({required this.support});

  final SupportSummary support;

  @override
  Widget build(BuildContext context) {
    final s = support;
    final seat = s.fixedSeat;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.accessibility_new_rounded,
            color: AppTheme.violet,
            title: t('info.support'),
          ),
          if (s.escortRequired)
            _Line(
              icon: Icons.person_pin_rounded,
              color: AppTheme.violet,
              text: t('info.escortRequired'),
            ),
          if (s.wheelchairVehicleRequired)
            _Line(
              icon: Icons.accessible_rounded,
              color: AppTheme.violet,
              text: t('info.rampVehicle'),
            ),
          if (seat != null)
            _Line(
              icon: Icons.event_seat_outlined,
              color: AppTheme.violet,
              text: seat is String && seat.isNotEmpty
                  ? tv('info.fixedSeatAt', {'seat': seat})
                  : t('info.fixedSeat'),
            ),
          if (s.doNotReleaseAlone)
            _Line(
              icon: Icons.shield_outlined,
              color: AppTheme.violet,
              text: t('info.neverAlone'),
            ),
        ],
      ),
    );
  }
}

/// A sentence with its own leading mark — the same row shape [_Section] uses,
/// for the facts that are a phrase rather than a label and a value.
class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
