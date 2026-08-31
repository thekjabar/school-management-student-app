import 'package:flutter/material.dart';

import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/settings_widgets.dart';
import 'home_address_screen.dart';

/// The guardian's own details, and the honest truth about which of them they
/// can change from a phone.
///
/// Both entry points to this used to be a toast — "the school office keeps
/// these details" — over a screen that never opened. A message that fires on
/// tap and leaves nothing behind reads as a refusal, and the customer said so:
/// while a parent cannot change them, why put them there at all.
///
/// So: the details are shown, because a parent has every reason to check what
/// the school holds against them; the two things that ARE theirs to change —
/// their password and where the family lives — are rows that actually go
/// somewhere; and the office's ownership of the rest is stated ONCE, at the
/// foot, as a sentence rather than as a toast on every tap.
///
/// Nothing here is invented. Every value comes from [Session.instance.me], and
/// a value the account does not hold is left out rather than drawn as a dash.
class PersonalInfoScreen extends StatelessWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final me = Session.instance.me;

    final facts = <_FactSpec>[
      if (me != null) ...[
        if (me.name.trim().isNotEmpty)
          _FactSpec(
            icon: Icons.person_outline_rounded,
            label: t('profile.fullName'),
            value: me.name,
          ),
        if (me.phone.trim().isNotEmpty)
          _FactSpec(
            icon: Icons.phone_outlined,
            label: t('profile.phone'),
            value: me.phone,
            // A phone number reads left-to-right even on a Kurdish screen;
            // mirroring it makes it unusable.
            ltr: true,
            badge: me.phoneVerified
                ? Pill(t('personal.verified'), color: AppTheme.green)
                : Pill(t('more.unverified'), color: AppTheme.amber),
            // Said only when it is true, and only on the row it is about.
            note: me.phoneVerified ? null : t('personal.phoneUnverifiedNote'),
          ),
        if (me.schoolName.trim().isNotEmpty)
          _FactSpec(
            icon: Icons.account_balance_outlined,
            label: t('profile.school'),
            value: me.schoolName,
          ),
        _FactSpec(
          icon: Icons.badge_outlined,
          label: t('profile.role'),
          value: t('profile.parent'),
        ),
      ],
    ];

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('profile.personal')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 24),
                children: [
                  if (facts.isNotEmpty) ...[
                    Card16(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionRow(title: t('personal.details')),
                          for (var i = 0; i < facts.length; i++)
                            _Fact(spec: facts[i], last: i == facts.length - 1),
                        ],
                      ),
                    ),
                    const SizedBox(height: kCardGap),
                  ],

                  // The two that are genuinely the parent's to change. Both
                  // already work today; neither is new here.
                  Card16(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionRow(title: t('personal.canChange')),
                        TileRow(
                          icon: Icons.lock_outline_rounded,
                          color: tint,
                          title: t('more.changePassword'),
                          subtitle: t('more.changePasswordSub'),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ChangePasswordSheet(tint: tint),
                          ),
                        ),
                        TileRow(
                          icon: Icons.home_outlined,
                          color: tint,
                          title: t('more.homeAddress'),
                          subtitle: t('more.homeAddressSub'),
                          last: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HomeAddressScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: kCardGap),
                  const _OfficeHoldsTheRest(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * The seam
 * ------------------------------------------------------------------------- */

/// The one line that says who owns the rest of these details.
///
/// Once, at the foot — not a caption under every row, and not a toast. The
/// parent reads it while looking at the values it is about, which is the only
/// moment it is useful.
///
/// THIS IS WHERE THE REQUEST FLOW LANDS. Deliberately no button yet: the
/// request-and-approve endpoint is not deployed, and a button that only shows
/// a message is the exact complaint this screen was built to answer.
class _OfficeHoldsTheRest extends StatelessWidget {
  const _OfficeHoldsTheRest();

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      icon: Icons.account_balance_outlined,
      title: t('personal.officeTitle'),
      body: t('personal.officeBody'),
      color: Role.parent.tint,
      // TODO(request-flow): when the correction endpoint is live, the "Ask the
      // office to correct this" button goes HERE — pass `action:` (a new
      // `t('personal.askOffice')` string, not yet added) and `onAction:` to
      // this NoticeBanner. It already draws a filled button in that slot in the
      // role's colour, so nothing else on this screen has to move.
    );
  }
}

/* ---------------------------------------------------------------------------
 * The details themselves
 * ------------------------------------------------------------------------- */

/// One read-only fact about the person signed in.
class _FactSpec {
  const _FactSpec({
    required this.icon,
    required this.label,
    required this.value,
    this.ltr = false,
    this.badge,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Force left-to-right, for values that are not words.
  final bool ltr;

  /// A status word on the right — whether the office has verified the number.
  final Widget? badge;

  /// A sentence under the value, when the status needs explaining.
  final String? note;
}

class _Fact extends StatelessWidget {
  const _Fact({required this.spec, required this.last});

  final _FactSpec spec;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip36(
            icon: spec.icon,
            color: tint,
            background: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
            size: 34,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
                Text(
                  spec.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: spec.ltr ? TextDirection.ltr : null,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
                if (spec.note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    spec.note!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (spec.badge != null) ...[
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 7), child: spec.badge!),
          ],
        ],
      ),
    );
  }
}
