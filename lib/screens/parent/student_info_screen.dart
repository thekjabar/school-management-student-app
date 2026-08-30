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
            ScreenHeader(title: t('info.title'), onBell: () {}),
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

                    _Section(
                      title: t('info.atSchool'),
                      icon: Icons.school_outlined,
                      color: tint,
                      rows: [
                        _Row(t('info.class'), p.className),
                        _Row(t('info.grade'), p.gradeLabel ?? _grade(p.gradeLevel)),
                        _Row(t('info.section'), p.section),
                        _Row(t('info.room'), p.room),
                        _Row(t('info.shift'), humanise(p.shift)),
                        _Row(t('info.teacher'), p.homeroomTeacher),
                        _Row(t('info.rollNo'), p.rollNo),
                      ],
                    ),
                    const SizedBox(height: kCardGap),

                    _Section(
                      title: t('info.enrolment'),
                      icon: Icons.badge_outlined,
                      color: AppTheme.blue,
                      rows: [
                        _Row(t('info.studentNo'), p.code),
                        _Row(t('info.year'), p.academicYear),
                        _Row(t('info.campus'), p.campusName),
                        _Row(t('info.address'), p.campusAddress),
                        _Row(t('info.since'), longDate(p.enrolledAt)),
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

/// The photograph, the name, and the two things everyone asks for first.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.tint});

  final ChildProfile profile;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final p = profile;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: p.photoUrl, name: p.name, tint: tint),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    // The full enrolled name, because the reason to look is
                    // usually to check a spelling against a document.
                    Text(
                      p.fullName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.25,
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (p.className != null) StatusChip(p.className!, color: tint),
                        StatusChip('#${p.code}', color: AppTheme.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.dob != null || p.gender != null || p.nationality != null) ...[
            const SizedBox(height: 13),
            Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 12),
            Row(
              children: [
                if (p.dob != null)
                  Expanded(
                    child: _Fact(
                      label: t('info.born'),
                      value: shortDate(p.dob),
                      // The age is the part a parent reads; the date is the
                      // part they check.
                      caption: p.ageYears == null
                          ? null
                          : tv('info.yearsOld', {'n': '${p.ageYears}'}),
                    ),
                  ),
                if (p.gender != null)
                  Expanded(child: _Fact(label: t('info.gender'), value: humanise(p.gender))),
                if (p.nationality != null)
                  Expanded(
                    child: _Fact(label: t('info.nationality'), value: p.nationality),
                  ),
              ],
            ),
          ],
        ],
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
    const size = 64.0;

    // No photograph is the norm rather than the exception here: plenty of
    // families do not consent to one, and the record honours that. Initials
    // are not a placeholder for a missing image, they are the answer.
    Widget fallback() => Center(
          child: Text(
            _initials(name),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
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
        borderRadius: BorderRadius.circular(18),
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

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.caption});

  final String label;
  final String? value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value ?? '—',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppTheme.text,
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
      ],
    );
  }
}

/// A label and a value. Null values are dropped by [_Section].
class _Row {
  const _Row(this.label, this.value);
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, color: color, title: title),
          const SizedBox(height: 10),
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.value!,
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.people_alt_outlined,
            color: AppTheme.green,
            title: t('info.guardians'),
          ),
          const SizedBox(height: 4),
          for (final g in guardians)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.isYou ? tv('info.you', {'name': g.name}) : g.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppTheme.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          humanise(g.relationship),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Who the office rings first. Worth being explicit about,
                  // because families frequently believe it is the other parent.
                  if (g.isPrimary) StatusChip(t('info.mainContact'), color: tint),
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.medical_services_outlined,
            color: AppTheme.rose,
            title: t('info.medical'),
          ),
          if (m.flags.isNotEmpty) ...[
            const SizedBox(height: 11),
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
          if (m.carriesMedication) ...[
            const SizedBox(height: 10),
            _Line(
              icon: Icons.medication_outlined,
              text: m.medicationLocation == null || m.medicationLocation!.isEmpty
                  ? t('info.carriesMedication')
                  : tv('info.carriesMedicationAt', {'where': m.medicationLocation!}),
            ),
          ],
          if (m.emergencyContacts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Line(
              icon: Icons.phone_in_talk_outlined,
              text: tv('info.ringInOrder', {'names': m.emergencyContacts.join(' → ')}),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            icon: Icons.accessibility_new_rounded,
            color: AppTheme.violet,
            title: t('info.support'),
          ),
          const SizedBox(height: 6),
          if (s.escortRequired)
            _Line(icon: Icons.person_pin_rounded, text: t('info.escortRequired')),
          if (s.wheelchairVehicleRequired)
            _Line(icon: Icons.accessible_rounded, text: t('info.rampVehicle')),
          if (seat != null)
            _Line(
              icon: Icons.event_seat_outlined,
              text: seat is String && seat.isNotEmpty
                  ? tv('info.fixedSeatAt', {'seat': seat})
                  : t('info.fixedSeat'),
            ),
          if (s.doNotReleaseAlone)
            _Line(icon: Icons.shield_outlined, text: t('info.neverAlone')),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppTheme.textMuted),
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
