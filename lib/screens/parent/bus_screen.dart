import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/parent_api.dart';
import '../../api/push.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// Where the bus is, and when it gets there.
///
/// One question, asked at 07:40 with a coat half on. The ETA is the largest
/// thing on the screen; everything under it is what a parent reads once and
/// then never again — the driver's name, the plate, the number to ring.
class BusScreen extends StatefulWidget {
  const BusScreen({super.key, required this.child});

  final Child child;

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final _loaderKey = GlobalKey<LoaderState<_Bus>>();
  Timer? _tick;
  bool _dismissedAlerts = false;

  @override
  void initState() {
    super.initState();
    // A live position that does not move is not live. Half a minute is often
    // enough to see the bus turn into the street.
    _tick = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loaderKey.currentState?.reload(),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: t('bus.title'),
              trailing: ChildPill(
                name: widget.child.name,
                line: widget.child.className,
                tint: tint,
              ),
            ),
            Expanded(
              child: Loader<_Bus>(
                key: _loaderKey,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 20),
                load: () async {
                  final r = await Future.wait([
                    ParentApi.instance.transport(widget.child.studentId),
                    ParentApi.instance.live(),
                  ]);
                  final buses = r[1] as List<LiveBus>;
                  return _Bus(
                    transport: r[0] as TransportInfo,
                    live: buses
                        .where((b) => b.studentId == widget.child.studentId)
                        .firstOrNull,
                  );
                },
                builder: (context, bus) {
                  if (!bus.transport.ridesTheBus) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 50),
                      child: Center(
                        child: Text(
                          t('bus.notOnBus'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ),
                    );
                  }

                  final trip = bus.run;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MapCard(bus: bus),
                      const SizedBox(height: kCardGap),
                      _RouteCard(bus: bus),
                      const SizedBox(height: kCardGap),
                      _Tiles(bus: bus, trip: trip),
                      if (!_dismissedAlerts && !Push.granted) ...[
                        const SizedBox(height: kCardGap),
                        NoticeBanner(
                          icon: Icons.notifications_active_rounded,
                          color: tint,
                          title: t('bus.getNotified'),
                          body: t('bus.getNotifiedBody'),
                          action: t('bus.enableAlerts'),
                          onAction: _enableAlerts,
                          onClose: () => setState(() => _dismissedAlerts = true),
                        ),
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

  Future<void> _enableAlerts() async {
    final ok = await Push.askPermission();
    if (!mounted) return;
    setState(() {});
    if (!ok) showNote(context, t('more.pushBlocked'));
  }
}

class _Bus {
  _Bus({required this.transport, required this.live});

  final TransportInfo transport;
  final LiveBus? live;

  /// The run this screen is about: the afternoon one once it is under way, the
  /// morning one until then.
  TripToday? get run {
    if (transport.today.isEmpty) return null;
    final back = transport.today.where((t) => t.leg == 'RETURN').toList();
    if (back.isNotEmpty && (back.first.boardedAt != null || back.first.status == 'IN_PROGRESS')) {
      return back.first;
    }
    final out = transport.today.where((t) => t.leg == 'OUT').toList();
    return out.isNotEmpty ? out.first : transport.today.first;
  }

  bool get moving => run?.status == 'IN_PROGRESS';
}

/* ---------------------------------------------------------------------------
 * The map that is not a map
 * ------------------------------------------------------------------------- */

class _MapCard extends StatelessWidget {
  const _MapCard({required this.bus});

  final _Bus bus;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final eta = bus.live?.etaMinutes;
    final trip = bus.run;

    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              // The route drawn, not mapped. There is no tile provider in this
              // app; a decorative street map would be a picture of somewhere
              // else, and a parent would read it as where their child is.
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoutePainter(
                    progress: bus.moving ? 0.55 : (trip?.endedAt != null ? 1 : 0.08),
                    tint: tint,
                    track: AppTheme.border,
                    ground: tint.withValues(alpha: AppTheme.dark ? 0.08 : 0.05),
                  ),
                ),
              ),

              PositionedDirectional(
                start: 10,
                top: 10,
                child: _Callout(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: bus.moving ? AppTheme.green : AppTheme.textFaint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            bus.moving ? t('bus.onTheWay') : t('bus.noRunTitle'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: bus.moving ? AppTheme.green : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.sensors_rounded, size: 13, color: AppTheme.textMuted),
                          const SizedBox(width: 5),
                          Text(
                            bus.live?.visible == true ? t('bus.live') : t('bus.notLive'),
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      if (eta != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$eta',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                height: 1,
                                color: tint,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                t('bus.min'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tint,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          t('bus.estimatedArrival'),
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ],
                      if (trip?.scheduledDepartureAt != null)
                        Text(
                          hhmm(trip!.scheduledDepartureAt),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              PositionedDirectional(
                end: 10,
                top: 10,
                child: _Callout(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.account_balance_rounded, size: 16, color: tint),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              bus.transport.dropoffStopName ?? t('driver.school'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                          ),
                          Text(
                            '${t('bus.eta')} ${hhmm(trip?.scheduledDepartureAt)}',
                            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              PositionedDirectional(
                start: 10,
                bottom: 10,
                child: _Callout(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.home_rounded, size: 16, color: tint),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              bus.transport.pickupStopName ?? t('bus.home'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                          ),
                          Text(
                            hhmm(trip?.startedAt ?? trip?.scheduledDepartureAt),
                            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              PositionedDirectional(
                end: 12,
                bottom: 12,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A101828), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Icon(Icons.my_location_rounded, size: 19, color: tint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(color: Color(0x14101828), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.progress,
    required this.tint,
    required this.track,
    required this.ground,
  });

  final double progress;
  final Color tint;
  final Color track;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);

    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.88)
      ..cubicTo(
        size.width * 0.30, size.height * 0.80,
        size.width * 0.34, size.height * 0.62,
        size.width * 0.52, size.height * 0.56,
      )
      ..cubicTo(
        size.width * 0.70, size.height * 0.50,
        size.width * 0.72, size.height * 0.26,
        size.width * 0.86, size.height * 0.22,
      );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = track,
    );

    final metric = path.computeMetrics().first;
    final done = metric.extractPath(0, metric.length * progress.clamp(0, 1));
    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = tint,
    );

    // The two ends, then the bus where the driven part stops.
    for (final at in [0.0, 1.0]) {
      final p = metric.getTangentForOffset(metric.length * at)!.position;
      canvas.drawCircle(p, 7, Paint()..color = tint);
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      );
    }

    final head = metric.getTangentForOffset(metric.length * progress.clamp(0, 1))!.position;
    canvas.drawCircle(head, 20, Paint()..color = tint.withValues(alpha: 0.18));
    canvas.drawCircle(head, 13, Paint()..color = tint);
    canvas.drawCircle(
      head,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.progress != progress || old.tint != tint;
}

/* ---------------------------------------------------------------------------
 * The run
 * ------------------------------------------------------------------------- */

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.bus});

  final _Bus bus;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final trip = bus.run;
    if (trip == null) {
      return Card16(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(
            t('bus.noRunToday'),
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    // Five milestones, each either behind, happening, or ahead — derived from
    // the trip's own timestamps rather than stored as a stage.
    final steps = <(String, String, DateTime?, int)>[
      (t('bus.started'), t('driver.depot'), trip.startedAt, trip.startedAt != null ? 2 : 0),
      (
        tn('bus.arrivedAt', bus.transport.pickupStopName ?? t('bus.home')),
        bus.transport.pickupLandmark ?? '',
        trip.boardedAt,
        trip.boardedAt != null ? 2 : (trip.startedAt != null ? 1 : 0),
      ),
      (
        t('bus.onTheWay'),
        t('bus.headingToSchool'),
        null,
        trip.alightedAt != null ? 2 : (trip.boardedAt != null ? 1 : 0),
      ),
      (
        t('bus.nextStop'),
        trip.stopName ?? '',
        null,
        trip.alightedAt != null ? 2 : 0,
      ),
      (
        t('bus.arriveAtSchool'),
        bus.transport.dropoffStopName ?? '',
        trip.alightedAt ?? trip.endedAt,
        trip.endedAt != null ? 2 : 0,
      ),
    ];

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.directions_bus_rounded, size: 17, color: tint),
              ),
              const SizedBox(width: 9),
              Text(
                t('bus.todaysRoute'),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.text,
                ),
              ),
              if ((bus.transport.routeName ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(child: StatusChip(bus.transport.routeName!, color: tint)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _Step(
              title: steps[i].$1,
              sub: steps[i].$2,
              at: steps[i].$3,
              state: steps[i].$4,
              first: i == 0,
              last: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.sub,
    required this.at,
    required this.state,
    required this.first,
    required this.last,
  });

  final String title;
  final String sub;
  final DateTime? at;

  /// 0 ahead, 1 happening, 2 behind.
  final int state;

  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final (colour, chip) = switch (state) {
      2 => (AppTheme.green, t('bus.completed')),
      1 => (tint, t('bus.liveNow')),
      _ => (AppTheme.textFaint, t('bus.upcoming')),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: first ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: state == 0 ? Colors.transparent : colour,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: state == 0 ? AppTheme.border : colour,
                      width: 2,
                    ),
                  ),
                  child: switch (state) {
                    2 => const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                    1 => const Icon(Icons.directions_bus_rounded, size: 13, color: Colors.white),
                    _ => null,
                  },
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: last ? Colors.transparent : AppTheme.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: state == 1
                    ? tint.withValues(alpha: AppTheme.dark ? 0.14 : 0.07)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      at == null ? '—' : hhmm(at),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppTheme.text,
                          ),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state == 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chip,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.sensors_rounded, size: 11, color: Colors.white),
                        ],
                      ),
                    )
                  else
                    StatusChip(chip, color: colour),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------------------
 * Who is driving
 * ------------------------------------------------------------------------- */

class _Tiles extends StatelessWidget {
  const _Tiles({required this.bus, required this.trip});

  final _Bus bus;
  final TripToday? trip;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final phone = trip?.driverPhone;

    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.directions_bus_rounded,
            colour: tint,
            label: t('driver.busNumber'),
            value: trip?.vehicleLabel ?? trip?.plate ?? '—',
            valueColour: tint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            icon: Icons.person_rounded,
            colour: AppTheme.amber,
            label: t('bus.driver'),
            value: trip?.driverName ?? '—',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            icon: Icons.phone_rounded,
            colour: AppTheme.blue,
            label: t('bus.driverPhone'),
            value: phone ?? '—',
            caption: phone == null ? null : t('bus.callAnytime'),
            captionColour: AppTheme.blue,
            onTap: phone == null
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: phone));
                    if (context.mounted) showNote(context, t('bus.numberCopied'));
                  },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          // The design puts "Safety — Verified — Background checked" here.
          // Nothing in the platform records a driver's vetting, so that tile
          // would be a reassurance the app invented about the person a child
          // gets into a vehicle with. The seat is a real fact about this child
          // on this bus, and it is what a parent asks the office about.
          child: _Tile(
            icon: Icons.event_seat_rounded,
            colour: AppTheme.rose,
            label: t('bus.seat'),
            value: bus.transport.seatNumber ?? '—',
            caption: bus.transport.routeName,
            captionColour: AppTheme.rose,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.colour,
    required this.label,
    required this.value,
    this.caption,
    this.captionColour,
    this.valueColour,
    this.onTap,
  });

  final IconData icon;
  final Color colour;
  final String label;
  final String value;
  final String? caption;
  final Color? captionColour;
  final Color? valueColour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: colour),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: valueColour ?? AppTheme.text,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                caption!,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: captionColour ?? AppTheme.textFaint,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
