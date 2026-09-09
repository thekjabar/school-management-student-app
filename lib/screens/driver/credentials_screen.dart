import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/client.dart';
import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import 'crew_account.dart';

/// A driver's own paperwork, and the date it stops him driving.
///
/// fleet-service has served this since credentials were built, and its own
/// docstring says exactly why: "knowing that his licence stops counting on the
/// 16th rather than the 30th is the entire reason the lead time exists". The
/// app never asked for it.
///
/// So the sequence was this. A licence passes its block date. The roster
/// controller sets the trip to BLOCKED. At twenty to seven the driver taps
/// "start the run" and gets "This bus is blocked: crew credential expired",
/// with forty children arriving at a stop nobody is driving to — about a date
/// the server had known for weeks and had a warning window built to announce.
///
/// He also could not do anything about it from here. `POST /crew/me/credentials`
/// has always accepted a photograph of the renewed document; there was no kind
/// of file a crew handset was allowed to produce that could BE that photograph,
/// so the renewal meant a trip to the depot with a piece of paper.
///
/// Lives inside the papers screen rather than as a screen of its own: a driver
/// looking for his licence expiry looks under "my papers", and two places
/// showing the same documents is how they come to disagree.
class CredentialsPanel extends StatefulWidget {
  const CredentialsPanel({super.key});

  @override
  State<CredentialsPanel> createState() => _CredentialsPanelState();
}

class _CredentialsPanelState extends State<CredentialsPanel> {
  // Loaded into state rather than through a Loader, because this sits inside
  // the papers screen's own Loader — and Loader renders an unbounded ListView,
  // so nesting one inside a Column would throw on layout rather than merely
  // look wrong.
  List<Credential>? _rows;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await CrewApi.instance.myCredentials();
      if (mounted) setState(() { _rows = rows; _failed = false; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _renew(Credential c) async {
    final source = await pickOne<ImageSource>(
      context,
      tint: Role.driver.tint,
      title: t('cred.sendNew'),
      options: [
        PickOption(
          value: ImageSource.camera,
          label: t('cred.photograph'),
          icon: Icons.photo_camera_rounded,
        ),
        PickOption(
          value: ImageSource.gallery,
          label: t('cred.fromPhone'),
          icon: Icons.photo_library_rounded,
        ),
      ],
    );
    if (source == null) return;

    setState(() => _busy = true);
    try {
      final shot = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 80,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      final assetId = await CrewApi.instance.uploadCredentialPhoto(
        bytes: bytes,
        // image_picker re-encodes to JPEG whenever imageQuality is set, so the
        // name and the type must say JPEG whatever the original was — the
        // upload route checks the part's content type against the kind.
        filename: 'document.jpg',
        mime: 'image/jpeg',
      );
      await CrewApi.instance.submitCredential(kind: c.kind, documentAssetId: assetId);
      if (!mounted) return;
      showNote(context, t('cred.sentForChecking'));
      await _load();
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    } catch (_) {
      if (mounted) showNote(context, t('cred.sendFailed'), bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    if (_failed) {
      return Panel(
        child: Row(
          children: [
            Expanded(
              child: Text(
                t('cred.loadFailed'),
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _failed = false);
                _load();
              },
              style: TextButton.styleFrom(foregroundColor: Role.driver.tint),
              child: Text(t('cred.retry')),
            ),
          ],
        ),
      );
    }
    if (rows == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: Role.driver.tint),
        ),
      );
    }
    if (rows.isEmpty) {
      return Panel(
        child: Text(
          t('driver.noPapers'),
          style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
        ),
      );
    }

    // Whatever is stopping him driving goes first, then whatever is about to.
    // A list in filing order is one where the row that matters is third, under
    // two that do not.
    final sorted = [...rows]..sort((a, b) {
        int rank(Credential c) => c.blocking ? 0 : (c.expiringSoon ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return (a.daysUntilRosterBlock ?? 9999).compareTo(b.daysUntilRosterBlock ?? 9999);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in sorted) ...[
          _CredentialCard(credential: c, busy: _busy, onRenew: () => _renew(c)),
          const SizedBox(height: kCardGap),
        ],
        const SizedBox(height: 4),
        Text(
          t('cred.officeChecks'),
          style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textFaint),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CredentialCard extends StatelessWidget {
  const _CredentialCard({
    required this.credential,
    required this.busy,
    required this.onRenew,
  });

  final Credential credential;
  final bool busy;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final c = credential;
    final (Color colour, String word) = c.blocking
        ? (AppTheme.rose, t('cred.state.blocking'))
        : c.expiringSoon
            ? (AppTheme.amber, t('cred.state.soon'))
            : c.derivedStatus == 'PENDING_VERIFICATION'
                ? (AppTheme.blue, t('cred.state.checking'))
                : (AppTheme.green, t('cred.state.ok'));

    final days = c.daysUntilRosterBlock;

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(c.kind), size: 20, color: colour),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.label.isEmpty ? c.kind : c.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.text,
                      ),
                    ),
                    if ((c.number ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.number!,
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(word, color: colour),
            ],
          ),
          const SizedBox(height: 10),

          // The date that actually matters, said as a countdown rather than as
          // a date. "Stops counting in 9 days" is something a person acts on;
          // "rosterBlockFrom: 16 March" is something they file away.
          if (days != null)
            Text(
              days <= 0
                  ? t('cred.blockedNow')
                  : tn('cred.stopsInDays', days),
              style: TextStyle(
                fontSize: 13,
                fontWeight: c.blocking || c.expiringSoon ? FontWeight.w700 : FontWeight.w500,
                color: c.blocking || c.expiringSoon ? colour : AppTheme.text,
              ),
            ),
          if (c.expiresOn != null) ...[
            const SizedBox(height: 3),
            Text(
              tv('cred.expiresOn', {'date': longDate(c.expiresOn)}),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
          if ((c.rejectedReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              c.rejectedReason!,
              style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.rose),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: busy ? null : onRenew,
              icon: const Icon(Icons.photo_camera_rounded, size: 18),
              label: Text(t('cred.sendNew')),
              style: FilledButton.styleFrom(
                backgroundColor: c.blocking || c.expiringSoon
                    ? colour
                    : AppTheme.neutralSoft,
                foregroundColor:
                    c.blocking || c.expiringSoon ? Colors.white : AppTheme.text,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
        'LICENCE' => Icons.badge_rounded,
        'MEDICAL' => Icons.medical_services_rounded,
        'VETTING' || 'CHILD_PROTECTION' => Icons.verified_user_rounded,
        'FIRST_AID' => Icons.health_and_safety_rounded,
        'TRAINING' || 'DEFENSIVE_DRIVING' => Icons.school_rounded,
        'NATIONAL_ID' || 'RESIDENCE_CARD' => Icons.credit_card_rounded,
        _ => Icons.description_rounded,
      };
}

/// The line on the home screen that stops a driver finding out at the depot.
///
/// Deliberately on the FIRST screen of the app rather than behind the profile
/// tab: the whole point is that he sees it on an ordinary morning, days before
/// it bites, without having gone looking for it. Renders nothing at all when
/// there is nothing to say, so it costs a compliant driver no space.
class CredentialWarning extends StatefulWidget {
  const CredentialWarning({super.key});

  @override
  State<CredentialWarning> createState() => _CredentialWarningState();
}

class _CredentialWarningState extends State<CredentialWarning> {
  List<Credential>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await CrewApi.instance.myCredentials();
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      // Silent. This is a warning that sits above the run, and a driver whose
      // paperwork is in order must never be shown an error about it — the run
      // itself is what this screen is for.
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null) return const SizedBox.shrink();

    final blocking = rows.where((c) => c.blocking).toList();
    final soon = rows.where((c) => c.expiringSoon).toList();
    if (blocking.isEmpty && soon.isEmpty) return const SizedBox.shrink();

    final worst = blocking.isNotEmpty ? blocking.first : soon.first;
    final colour = blocking.isNotEmpty ? AppTheme.rose : AppTheme.amber;
    final days = worst.daysUntilRosterBlock;

    return Padding(
      padding: const EdgeInsets.only(bottom: kCardGap),
      child: Card16(
        color: colour.withValues(alpha: AppTheme.dark ? 0.16 : 0.08),
        border: colour.withValues(alpha: 0.45),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CrewPapersScreen()),
        ),
        child: Row(
          children: [
            Icon(
              blocking.isNotEmpty
                  ? Icons.report_problem_rounded
                  : Icons.schedule_rounded,
              size: 22,
              color: colour,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    blocking.isNotEmpty
                        ? t('cred.warnBlockedTitle')
                        : tv('cred.warnSoonTitle', {
                            'doc': worst.label.isEmpty ? worst.kind : worst.label,
                          }),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colour,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    blocking.isNotEmpty
                        ? t('cred.warnBlockedBody')
                        : (days == null
                            ? t('cred.warnSoonBodyPlain')
                            : tn('cred.warnSoonBody', days)),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppTheme.text,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colour),
          ],
        ),
      ),
    );
  }
}
