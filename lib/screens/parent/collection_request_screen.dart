import 'package:flutter/material.dart';

import '../../api/biometrics.dart';
import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

/// "My brother is collecting my child today."
///
/// THIS SCREEN CANNOT AUTHORISE ANYTHING, AND THAT IS THE WHOLE DESIGN.
///
/// The one-off collection authorisation is a real object on the server —
/// students-service `school/one-time-authorizations` — but every route on it,
/// including the reads, is gated on ONE_TIME_AUTH_ISSUE, which is an office
/// permission. A guardian's token cannot create one, cannot read one and cannot
/// see the six-character code. That is deliberate on the server's part: the
/// code is a thing a stranger says at a door to walk away with a child, and the
/// school decides who gets one after satisfying itself, by a telephone callback
/// to the number ALREADY ON FILE, that the person asking is really the
/// guardian. A phone in a stranger's hand cannot be that check.
///
/// So what the family app can honestly offer is the ASKING. This composes the
/// request the office needs — who is collecting, how they are related, their
/// telephone, their identity card number, which day and which run — and puts it
/// on the dispatch board the office already watches, through POST
/// /parent/concerns with topic PICKUP_ARRANGEMENT. The office reads it, rings
/// the family back on the number it holds, and issues the code itself.
///
/// EVERY LINE HERE THAT COULD BE READ AS "DONE" HAS BEEN WRITTEN NOT TO BE. A
/// parent who believes the collection is arranged sends their brother to a
/// school that has never heard of him, and he is refused at the gate in front
/// of the child. That is the failure this screen is built around: the banner
/// says it is a request, the confirmation before sending says it again with the
/// collector's name in it, the receipt after sending says it a third time, and
/// no status this screen can show is ever coloured or worded as permission —
/// not even CLOSED, which only means a dispatcher tidied their board.
///
/// It also declines to encourage the two patterns the server's anomaly detector
/// (one-time-auth-anomaly.service.ts) exists to catch. One day and one run per
/// request, never a range, and a standing footnote telling a family whose uncle
/// collects every Thursday to ask for a permanent authorised collector instead
/// — which is exactly what that detector says a repeating "one-off" should have
/// been. And there is no resend button: the concern route merges a repeat into
/// the open row and the newest text WINS, so a second request silently replaces
/// the first on the office's board. When the server's answer says that has
/// happened, this screen says so in as many words.
///
/// That merge is only ever into a request the office STILL HAS. Once they have
/// closed it — which is how this flow normally ends, since they ring and then
/// tidy their board — the next request is a new row and a new occurrence count,
/// and the "this replaced the earlier one" line is correctly not shown. It used
/// not to be: the dedupe key never varied, so the second request a family ever
/// sent about a child broke a unique constraint and came back to them as a
/// database sentence. The list below is filtered to collection requests for the
/// same reason it is worded the way it is — every line under it is about
/// somebody being handed a child, and nothing else may be drawn there.
class CollectionRequestScreen extends StatefulWidget {
  const CollectionRequestScreen({super.key, required this.child, this.ridesTheBus = true});

  final Child child;

  /// Whether this child travels on a school bus at all.
  ///
  /// A child who does NOT is the population this screen is most for — they are
  /// collected at the gate every day, and the person collecting is the only
  /// question — so the form must not ask them which BUS RUN their uncle is
  /// meeting. The office reads that line off the board and rings the family
  /// about a bus the child has never been on.
  final bool ridesTheBus;

  @override
  State<CollectionRequestScreen> createState() => _CollectionRequestScreenState();
}

class _CollectionRequestScreenState extends State<CollectionRequestScreen> {
  final _loaderKey = GlobalKey<LoaderState<List<ConcernStatus>>>();

  String get _firstName => widget.child.name.split(' ').first;

  Future<void> _open() async {
    final sent = await showAppSheet<_Sent>(
      context,
      builder: (_) => _RequestSheet(child: widget.child, ridesTheBus: widget.ridesTheBus),
    );
    if (sent == null || !mounted) return;

    // The receipt, and the only place the word "sent" appears. It says what was
    // sent, what has NOT happened, and — when the server's own answer shows
    // this request was merged into one already open — that the office can no
    // longer see the earlier arrangement.
    //
    // One button, because there is nothing to decide here, and amber rather
    // than green: green is the colour this app uses for a thing that has been
    // settled, and nothing has been settled.
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
      builder: (_) => _Receipt(
        title: t('ota.sentTitle'),
        body: sent.replacedAnother
            ? '${tn('ota.sentBody', _firstName)}\n\n${tn('ota.sentReplaced', _firstName)}'
            : tn('ota.sentBody', _firstName),
      ),
    );
    if (!mounted) return;
    _loaderKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        backgroundColor: tint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.how_to_reg_rounded),
        label: Text(t('ota.new')),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('ota.title')),
            ChildCard(
              name: widget.child.name,
              line: '${widget.child.className}  •  ${widget.child.code}',
              tint: tint,
            ),
            Expanded(
              child: Loader<List<ConcernStatus>>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 96),
                // Collection requests ONLY. This list is drawn with wording that
                // is true of nothing else the family can send: "Closed on the
                // office board. That is not the school giving permission." A
                // BUS_LATE row rendered under that line tells a family the
                // school has declined a collection nobody ever asked about.
                load: () => ParentApi.instance.concerns(
                      studentId: widget.child.studentId,
                      topic: 'PICKUP_ARRANGEMENT',
                    ),
                builder: (context, rows) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tn('ota.lead', _firstName),
                        style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 12),

                      // The first thing on the screen, above the button that
                      // starts the form, because it is the thing a family has
                      // to have read before they act on any of this.
                      NoticeBanner(
                        icon: Icons.gpp_maybe_rounded,
                        color: AppTheme.amber,
                        title: t('ota.notPermissionTitle'),
                        body: tn('ota.notPermissionBody', _firstName),
                      ),
                      const SizedBox(height: kCardGap),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.phone_in_talk_rounded, size: 16, color: AppTheme.textFaint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t('ota.answeredByPhone'),
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // The nudge away from the pattern the anomaly detector
                      // flags: a "one-off" that happens every week is an
                      // arrangement, and an arrangement belongs on the child's
                      // permanent collector list with an approval behind it.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.repeat_rounded, size: 16, color: AppTheme.textFaint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tn('ota.standing', _firstName),
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: AppTheme.textFaint,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      Text(
                        tn('ota.yours', _firstName),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (rows.isEmpty)
                        Text(
                          tn('ota.none', _firstName),
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        )
                      else
                        for (final r in rows) ...[
                          _RequestCard(row: r),
                          const SizedBox(height: kCardGap),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the sheet hands back. Not the arrangement — there is no arrangement —
/// only what the server said about where the message landed.
class _Sent {
  const _Sent({required this.replacedAnother});

  /// The server merged this into a request already open for this child and this
  /// topic, and its `body` — the only thing the office actually reads — is now
  /// this message and not the earlier one.
  final bool replacedAnother;
}

/// One request the office has, and what its state does NOT mean.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.row});

  final ConcernStatus row;

  @override
  Widget build(BuildContext context) {
    // No green anywhere in here, on purpose.
    //
    // CLOSED is the state a family is most likely to misread, and it is the one
    // that would do the damage: it means a dispatcher marked the row resolved
    // on their board, which they also do after ringing to say no. It is
    // rendered in the same neutral tone as the rest and carries a line saying
    // so in words.
    final (Color colour, String label, String meaning) = switch (row.state) {
      'SEEN' => (AppTheme.blue, t('ota.state.SEEN'), t('ota.stateMeaning.SEEN')),
      'CLOSED' => (AppTheme.textMuted, t('ota.state.CLOSED'), t('ota.stateMeaning.CLOSED')),
      _ => (AppTheme.amber, t('ota.state.SENT'), t('ota.stateMeaning.SENT')),
    };

    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppTheme.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pill(label, color: colour),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            row.timesRaised > 1
                ? '${longDate(row.raisedAt)}  •  ${tn('ota.timesSent', row.timesRaised)}'
                : longDate(row.raisedAt),
            style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            meaning,
            style: TextStyle(fontSize: 11.5, height: 1.4, color: colour),
          ),
        ],
      ),
    );
  }
}

/// The receipt. One button and no choice: the sending has happened, and the
/// only thing left is to be sure the family has read what has NOT happened.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_top_rounded, size: 30, color: AppTheme.amber),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppTheme.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.amber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  t('common.close'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The form.
class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.child, required this.ridesTheBus});

  final Child child;
  final bool ridesTheBus;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  /// Relations, not job titles. These are the people who actually turn up, and
  /// offering them as taps rather than a text box means the office reads the
  /// same seven words every time instead of forty spellings of "uncle".
  static const _relations = <(String, IconData)>[
    ('BROTHER', Icons.man_rounded),
    ('SISTER', Icons.woman_rounded),
    ('UNCLE', Icons.person_rounded),
    ('AUNT', Icons.person_2_rounded),
    ('GRANDPARENT', Icons.elderly_rounded),
    ('NEIGHBOUR', Icons.home_rounded),
    ('OTHER', Icons.more_horiz_rounded),
  ];

  /// The server's own ceiling on a concern message. Enforced here so that a
  /// long note costs the note and never the facts the office needs.
  static const _maxMessage = 600;

  /// How far ahead a family may ask. The code the office eventually issues
  /// lives at most a day, so it is written on the morning it is needed — but
  /// the ASKING is worth doing in advance, and a fortnight covers the trip to
  /// Erbil that prompts most of these.
  static const _maxDaysAhead = 14;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _note = TextEditingController();

  String _relation = 'BROTHER';
  String _leg = 'RETURN';
  DateTime _day = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The send button is disabled until there is a name to send, so the field
    // has to drive a rebuild.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _idNumber.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await pickDate(
      context,
      initial: _day,
      // Never a past day. Nobody can be authorised to have collected a child
      // yesterday, and offering it would only produce a request the office has
      // to ring up and unpick.
      first: today,
      last: today.add(const Duration(days: _maxDaysAhead)),
      tint: Role.parent.tint,
    );
    if (picked != null) setState(() => _day = picked);
  }

  /// Everything the office needs to ring back and issue a code, in the family's
  /// own language, on labelled lines so a dispatcher can read it at a glance.
  ///
  /// The server appends who sent it and their telephone number, so this does
  /// not repeat them. It is trimmed to the server's ceiling by dropping the
  /// note last — the name, the relation and the day are what a callback is
  /// made about; the note is context.
  String _message() {
    final lines = <String>[
      t('ota.msg.heading'),
      '${t('ota.msg.who')} ${_name.text.trim()}',
      '${t('ota.msg.relation')} ${t('ota.rel.$_relation')}',
      if (_phone.text.trim().isNotEmpty) '${t('ota.msg.phone')} ${_phone.text.trim()}',
      if (_idNumber.text.trim().isNotEmpty) '${t('ota.msg.id')} ${_idNumber.text.trim()}',
      '${t('ota.msg.day')} ${longDate(_day)}',
      // A child who is not on a bus has no run to be met at, and saying "Run:
      // the run home" about one would send the office looking at a manifest
      // this child has never appeared on.
      if (widget.ridesTheBus)
        '${t('ota.msg.run')} ${t('ota.leg.$_leg')}'
      else
        t('ota.msg.atGate'),
    ];
    var out = lines.join('\n');

    final note = _note.text.trim();
    if (note.isNotEmpty) {
      final label = t('ota.msg.note');
      final room = _maxMessage - out.length - label.length - 2;
      if (room > 12) {
        final body = note.length > room ? note.substring(0, room) : note;
        out = '$out\n$label $body';
      }
    }
    return out.length > _maxMessage ? out.substring(0, _maxMessage) : out;
  }

  Future<void> _send() async {
    final who = _name.text.trim();
    if (who.length < 2) {
      setState(() => _error = t('ota.whoRequired'));
      return;
    }

    // Said once more, with the collector's name in it, at the last moment
    // before it goes. A family that taps through this has been told three times
    // that nobody may collect until the office rings, and the one they cannot
    // skip is the one that names the person they were about to send.
    final sure = await confirmDialog(
      context,
      icon: Icons.gpp_maybe_rounded,
      title: t('ota.confirmTitle'),
      body: tv('ota.confirmBody', {'who': who, 'n': widget.child.name.split(' ').first}),
      confirmLabel: t('ota.confirmSend'),
      confirmIcon: Icons.send_rounded,
      tone: AppTheme.amber,
    );
    if (!sure || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The same proof the skip and leave forms ask for, and for a stronger
      // reason: this names an adult to a school as somebody a child may be
      // handed to. It has to be the guardian holding the phone, not whoever
      // picked it up off the table.
      final ok = await Biometrics.confirm(reason: t('ota.confirmWithBiometrics'));
      if (!ok) {
        if (mounted) setState(() => _error = t('ota.notConfirmed'));
        return;
      }

      final res = await ParentApi.instance.raiseConcern(
        studentId: widget.child.studentId,
        // URGENT only when the collection is today, because URGENT is what puts
        // this in front of a dispatcher within minutes rather than on a board
        // to be worked through. A request about next Thursday is a real thing
        // to answer and not a reason to interrupt somebody watching buses.
        urgency: _isToday ? 'URGENT' : 'QUESTION',
        topic: 'PICKUP_ARRANGEMENT',
        message: _message(),
      );
      if (!mounted) return;
      final times = (res['timesRaised'] as num?)?.toInt() ?? 1;
      Navigator.of(context).pop(_Sent(replacedAnother: times > 1));
    } on ApiException catch (e) {
      // A 409 from this route is a dedupe-key collision, and the server's
      // exception filter renders it as the literal "That tenantId, dedupeKey is
      // already taken." That sentence is bookkeeping and it is being read under
      // a send button by somebody arranging for a person to be handed a child.
      // The generational key means it should no longer be reachable at all;
      // this is what is shown if it ever is, and it says the only two things
      // that matter — nothing went, and telephone if it is today.
      if (mounted) {
        setState(() => _error = e.status == 409
            ? tn('ota.notSent', widget.child.name.split(' ').first)
            : e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final inset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
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
                t('ota.newTitle'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tn('ota.newLine', widget.child.name.split(' ').first),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),

              _Label(t('ota.who')),
              const SizedBox(height: 8),
              _Field(
                controller: _name,
                hint: t('ota.whoHint'),
                maxLength: 80,
                autofocus: true,
                capitals: TextCapitalization.words,
              ),

              const SizedBox(height: 16),
              _Label(tn('ota.relation', widget.child.name.split(' ').first)),
              const SizedBox(height: 9),
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 8.0;
                  final w = (box.maxWidth - gap * 2) / 3;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final r in _relations)
                        SizedBox(
                          width: w,
                          child: _Tile(
                            label: t('ota.rel.${r.$1}'),
                            icon: r.$2,
                            on: r.$1 == _relation,
                            onTap: () => setState(() => _relation = r.$1),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              _Label(t('ota.phone')),
              const SizedBox(height: 8),
              _Field(
                controller: _phone,
                hint: t('ota.phoneHint'),
                maxLength: 24,
                keyboard: TextInputType.phone,
              ),

              const SizedBox(height: 16),
              _Label(t('ota.idNumber')),
              const SizedBox(height: 8),
              _Field(controller: _idNumber, hint: t('ota.idHint'), maxLength: 40),
              const SizedBox(height: 7),
              Text(
                tn('ota.idWhy', widget.child.name.split(' ').first),
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
              ),

              const SizedBox(height: 16),
              PickerField(
                label: t('ota.day'),
                value: longDate(_day),
                icon: Icons.calendar_today_rounded,
                onTap: _pickDay,
              ),

              // Not asked of a child who does not ride the bus: there is no run
              // to choose between, and an answer they were forced to invent
              // goes onto the office's board as a fact.
              if (widget.ridesTheBus) ...[
                const SizedBox(height: 16),
                _Label(t('ota.run')),
                const SizedBox(height: 9),
                Row(
                  children: [
                    for (final l in const ['OUT', 'RETURN']) ...[
                      Expanded(
                        child: _Choice(
                          label: t('ota.leg.$l'),
                          on: l == _leg,
                          onTap: () => setState(() => _leg = l),
                        ),
                      ),
                      if (l != 'RETURN') const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],

              if (_isToday) ...[
                const SizedBox(height: 14),
                _Warning(text: t('ota.todayUrgent')),
              ],

              const SizedBox(height: 16),
              _Label(t('ota.note')),
              const SizedBox(height: 8),
              _Field(
                controller: _note,
                hint: t('ota.notePlaceholder'),
                maxLength: 200,
                lines: 2,
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.rose, height: 1.35),
                ),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _busy || _name.text.trim().length < 2 ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: tint,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          t('ota.send'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              // The last word on the form is the same word as the first.
              Text(
                t('ota.formFoot'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppTheme.textMuted,
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.lines = 1,
    this.autofocus = false,
    this.keyboard,
    this.capitals = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int lines;
  final bool autofocus;
  final TextInputType? keyboard;
  final TextCapitalization capitals;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        maxLength: maxLength,
        maxLines: lines,
        keyboardType: keyboard,
        textCapitalization: capitals,
        style: TextStyle(fontSize: 14, color: AppTheme.text),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          filled: true,
          fillColor: AppTheme.canvas,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.border),
          ),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.10) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w700 : FontWeight.w600,
            color: on ? tint : AppTheme.text,
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: on ? tint.withValues(alpha: 0.10) : AppTheme.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? tint : AppTheme.border, width: on ? 1.4 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: on ? tint : AppTheme.textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                color: on ? tint : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.amber.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.priority_high_rounded, size: 17, color: AppTheme.amber),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, height: 1.35, color: AppTheme.amber),
              ),
            ),
          ],
        ),
      );
}
