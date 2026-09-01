import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../api/session.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
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
/// somewhere; and the office's ownership of the rest is now a request they can
/// raise here rather than a phone call they have to remember to make.
///
/// Nothing here is invented. Every value comes from [Session.instance.me], and
/// a value the account does not hold is left out rather than drawn as a dash.
/// The corrections list comes from the server and nothing else; when it cannot
/// be fetched the screen says so instead of drawing an empty one, because an
/// empty list and an unreachable server look identical and mean opposite
/// things to somebody waiting on an answer.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  /// Null until the first answer arrives — which is not the same as empty, and
  /// the two are drawn differently on purpose.
  List<ProfileChange>? _requests;

  /// Only used while [_requests] is still null: once there is a list on screen,
  /// a failed refresh is a note at the bottom rather than a page that empties
  /// itself.
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ParentApi.instance.profileChanges();
      if (!mounted) return;
      setState(() {
        _requests = rows;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_requests == null) {
        setState(() => _error = e);
      } else {
        showNote(context, errorText(e), bad: true);
      }
    }
  }

  /// The one the office has not answered yet, if there is one.
  ///
  /// The server refuses a second request while one is open, so this is what
  /// decides whether the banner offers a button at all. While the list is
  /// still loading — or failed to load — this is null and the button IS
  /// offered: assuming a request exists would lock a parent out of a form the
  /// server would have accepted.
  ProfileChange? get _pending {
    for (final r in _requests ?? const <ProfileChange>[]) {
      if (r.pending) return r;
    }
    return null;
  }

  /// Newest first. The API already promises this order; sorting a copy costs
  /// nothing and means a build that does not keep the promise still reads the
  /// way a parent expects.
  List<ProfileChange> get _rows {
    final list = [...?_requests];
    list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final me = Session.instance.me;
    final rows = _rows;
    final pending = _pending;

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
              child: RefreshIndicator(
                color: tint,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
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

                    // The two that are genuinely the parent's to change, plus
                    // the way back in for somebody who cannot fill in the
                    // "current password" box because they have forgotten it.
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
                          // No "forgotten your password" here.
                          //
                          // Somebody reading this screen is signed in, so they
                          // do not need the office to reset anything — the row
                          // directly above changes it. Asking the office is for
                          // the person who cannot get in at all, and that is
                          // offered on the sign-in screen where they are.
                          // Two doors to the same thing, one of which is not
                          // needed by anyone standing in front of it, is how a
                          // simple screen stops being simple.
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
                    _OfficeHoldsTheRest(pending: pending != null, onAsk: _ask),

                    if (_error != null && _requests == null) ...[
                      const SizedBox(height: kCardGap),
                      _ListFailed(error: _error!, onRetry: _load),
                    ],

                    if (rows.isNotEmpty) ...[
                      Heading(t('personal.requests')),
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: kCardGap),
                          child: _RequestCard(
                            item: r,
                            onWithdraw: () => _withdraw(r),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ask() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AskSheet(heldName: Session.instance.me?.name ?? ''),
    );
    if (sent != true) return;
    await _load();
    if (!mounted) return;
    showNote(context, t('personal.askSent'));
  }

  Future<void> _withdraw(ProfileChange item) async {
    final yes = await confirmDialog(
      context,
      icon: Icons.undo_rounded,
      tone: AppTheme.rose,
      title: t('personal.withdrawTitle'),
      body: t('personal.withdrawBody'),
      confirmLabel: t('personal.withdrawDo'),
      confirmIcon: Icons.undo_rounded,
    );
    if (!yes || !mounted) return;
    try {
      await ParentApi.instance.cancelProfileChange(item.id);
      await _load();
      if (!mounted) return;
      showNote(context, t('personal.withdrawn'));
    } catch (e) {
      if (!mounted) return;
      showNote(context, errorText(e), bad: true);
    }
  }
}

/* ---------------------------------------------------------------------------
 * The seam, filled
 * ------------------------------------------------------------------------- */

/// The one line that says who owns the rest of these details — and, now that
/// the endpoint exists, the button that does something about it.
///
/// Once, at the foot — not a caption under every row, and not a toast. The
/// parent reads it while looking at the values it is about, which is the only
/// moment it is useful.
///
/// While a request is open the button is not drawn and the sentence changes
/// instead. The server refuses a second request outright, and a form that
/// takes five boxes of typing before saying so is a worse refusal than one
/// line read before starting.
class _OfficeHoldsTheRest extends StatelessWidget {
  const _OfficeHoldsTheRest({required this.pending, required this.onAsk});

  final bool pending;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      icon: Icons.account_balance_outlined,
      title: t('personal.officeTitle'),
      body: pending ? t('personal.officePending') : t('personal.officeAsk'),
      color: Role.parent.tint,
      action: pending ? null : t('personal.askOffice'),
      onAction: pending ? null : onAsk,
    );
  }
}

/// The corrections list could not be fetched.
///
/// Said out loud rather than left as an absent section: "you have asked for
/// nothing" and "we could not ask" look the same and mean opposite things.
class _ListFailed extends StatelessWidget {
  const _ListFailed({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip36(
            icon: Icons.cloud_off_rounded,
            color: AppTheme.rose,
            background: AppTheme.rose.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
            size: 34,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('personal.requests'),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  errorText(error),
                  style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                t('common.tryAgain'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * One correction the parent has asked for
 * ------------------------------------------------------------------------- */

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item, required this.onWithdraw});

  final ProfileChange item;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final (colour, word) = _status(item.status);

    return Card16(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip36(
                icon: _icon(item.status),
                color: colour,
                background: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                size: 38,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('personal.requestTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tv('personal.askedOn', {'date': longDate(item.requestedAt)}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(word, color: colour),
            ],
          ),

          const SizedBox(height: 13),
          Text(
            t('personal.whatWasAsked'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textFaint,
            ),
          ),
          const SizedBox(height: 7),
          if (item.fields.isEmpty)
            Text(
              t('personal.fieldsUnknown'),
              style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
            )
          else
            for (final f in item.fields)
              _Asked(
                label: _label(f.field),
                value: f.value,
                // An address reads left-to-right whatever the screen does.
                ltr: f.field == 'email',
              ),

          if ((item.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              t('personal.yourNote'),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textFaint,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.reason!,
              style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textMuted),
            ),
          ],

          // The whole reason a refused request is worth showing at all. It
          // gets the status colour and a ground of its own rather than being
          // one more grey line, because "rejected" without the office's own
          // sentence beside it only tells a parent to ring and ask why.
          if ((item.decisionNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: AppTheme.dark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('personal.officeNote'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: colour,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.decisionNote!,
                    style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.text),
                  ),
                  if (item.decidedAt != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      tv('personal.decidedOn', {'date': longDate(item.decidedAt)}),
                      style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (item.pending) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: GestureDetector(
                onTap: onWithdraw,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppTheme.rose.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.undo_rounded, size: 15, color: AppTheme.rose),
                      const SizedBox(width: 7),
                      Text(
                        t('personal.withdraw'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.rose,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The same four words in the same four colours as a leave request. A parent
  /// who has learned what amber means on one screen should not have to learn
  /// it again on this one.
  static (Color, String) _status(String status) => switch (status) {
        'PENDING' => (AppTheme.amber, t('leave.pending')),
        'APPROVED' => (AppTheme.green, t('leave.approved')),
        'REJECTED' => (AppTheme.rose, t('leave.rejected')),
        _ => (AppTheme.textMuted, t('leave.cancelled')),
      };

  static IconData _icon(String status) => switch (status) {
        'PENDING' => Icons.schedule_rounded,
        'APPROVED' => Icons.check_circle_outline_rounded,
        'REJECTED' => Icons.cancel_outlined,
        _ => Icons.undo_rounded,
      };

  /// A field the server named. Anything outside the five it documents is
  /// printed as it came rather than dropped — a line that silently disappears
  /// is how a parent ends up arguing about a change they cannot see.
  static String _label(String field) => switch (field) {
        'nameGiven' => t('personal.fieldGiven'),
        'nameFather' => t('personal.fieldFather'),
        'nameGrandfather' => t('personal.fieldGrandfather'),
        'nameFamily' => t('personal.fieldFamily'),
        'email' => t('personal.fieldEmail'),
        _ => humanise(field),
      };
}

/// One "you asked for this" line inside a request card.
class _Asked extends StatelessWidget {
  const _Asked({required this.label, required this.value, required this.ltr});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: ltr ? TextDirection.ltr : null,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Asking for one
 * ------------------------------------------------------------------------- */

/// Four name boxes and an email, and nothing is filled in for you.
///
/// FOUR boxes, not one. The office searches on the parts — given, father,
/// grandfather, family — and a single "full name" box hands them one string to
/// take apart by guesswork, which is exactly the guesswork this sheet refuses
/// to do. The app itself only ever holds the joined name, so it prefills
/// nothing and shows that joined name above the boxes as a reference instead:
/// splitting it on spaces would put somebody's grandfather in the family box
/// and send that to the office over the parent's own name.
///
/// The phone number is not here.
class _AskSheet extends StatefulWidget {
  const _AskSheet({required this.heldName});

  /// What the school holds today, joined, shown for comparison only.
  final String heldName;

  @override
  State<_AskSheet> createState() => _AskSheetState();
}

class _AskSheetState extends State<_AskSheet> {
  final _given = TextEditingController();
  final _father = TextEditingController();
  final _grandfather = TextEditingController();
  final _family = TextEditingController();
  final _email = TextEditingController();
  final _reason = TextEditingController();

  bool _busy = false;
  String? _error;

  static const _maxReason = 250;

  @override
  void dispose() {
    _given.dispose();
    _father.dispose();
    _grandfather.dispose();
    _family.dispose();
    _email.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// Enough to catch a typed mistake and no more. The server is the authority
  /// on what it will accept; this only saves a round trip on "karwan@".
  static bool _looksLikeEmail(String value) {
    final at = value.indexOf('@');
    if (at < 1) return false;
    final dot = value.indexOf('.', at + 2);
    return dot > 0 && dot < value.length - 1;
  }

  Future<void> _send() async {
    final given = _given.text.trim();
    final father = _father.text.trim();
    final grandfather = _grandfather.text.trim();
    final family = _family.text.trim();
    final email = _email.text.trim();
    final reason = _reason.text.trim();

    if (given.isEmpty &&
        father.isEmpty &&
        grandfather.isEmpty &&
        family.isEmpty &&
        email.isEmpty) {
      setState(() => _error = t('personal.nothingToAsk'));
      return;
    }
    if (email.isNotEmpty && !_looksLikeEmail(email)) {
      setState(() => _error = t('personal.emailInvalid'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Only what was actually typed. An empty string on this endpoint CLEARS
      // the field, so a box left alone has to arrive as null rather than as
      // "" — otherwise opening the sheet to fix one name part would wipe the
      // other three off the record.
      await ParentApi.instance.askProfileChange(
        nameGiven: given.isEmpty ? null : given,
        nameFather: father.isEmpty ? null : father,
        nameGrandfather: grandfather.isEmpty ? null : grandfather,
        nameFamily: family.isEmpty ? null : family,
        email: email.isEmpty ? null : email,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // The server's own sentence, which is the only one that knows why —
      // "a request is already open", for instance.
      setState(() {
        _error = errorText(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final held = widget.heldName.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('personal.askOffice'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                t('personal.askSub'),
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              // What the school holds today, so the parent is correcting
              // something they can see rather than typing from memory.
              if (held.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.canvas,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 17, color: AppTheme.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('personal.heldNow'),
                              style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                            ),
                            Text(
                              held,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: AppTheme.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Why there are four boxes and not one, said before the typing
              // rather than in a validation message after it.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: AppTheme.dark ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 17, color: tint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t('personal.namePartsNote'),
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _Field(label: t('personal.fieldGiven'), controller: _given),
              const SizedBox(height: 12),
              _Field(label: t('personal.fieldFather'), controller: _father),
              const SizedBox(height: 12),
              _Field(label: t('personal.fieldGrandfather'), controller: _grandfather),
              const SizedBox(height: 12),
              _Field(label: t('personal.fieldFamily'), controller: _family),
              const SizedBox(height: 12),
              _Field(
                label: t('personal.fieldEmail'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                capitalise: false,
                ltr: true,
              ),
              const SizedBox(height: 16),

              Text(
                t('personal.reasonLabel'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reason,
                maxLines: 3,
                maxLength: _maxReason,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: t('personal.reasonHint'),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.rose),
                ),
              ],
              const SizedBox(height: 16),

              BigButton(
                label: t('personal.send'),
                color: tint,
                busy: _busy,
                onPressed: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled box in the sheet.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.capitalise = true,
    this.ltr = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool capitalise;

  /// Force left-to-right, for a value that is not words.
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: AppTheme.text,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textDirection: ltr ? TextDirection.ltr : null,
          textCapitalization:
              capitalise ? TextCapitalization.words : TextCapitalization.none,
          decoration: InputDecoration(
            hintText: t('personal.leaveEmptyHint'),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
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
