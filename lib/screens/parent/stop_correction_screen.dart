import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/map_tiles.dart';
import '../../ui/screen_kit.dart';

class StopToFix {
  const StopToFix({
    required this.id,
    required this.name,
    required this.landmark,
    required this.at,
    required this.pickup,
  });

  final String id;
  final String name;
  final String? landmark;

  final LatLng? at;

  final bool pickup;
}

class StopCorrectionScreen extends StatefulWidget {
  const StopCorrectionScreen({super.key, required this.child, required this.stops});

  final Child child;

  final List<StopToFix> stops;

  @override
  State<StopCorrectionScreen> createState() => _StopCorrectionScreenState();
}

class _StopCorrectionScreenState extends State<StopCorrectionScreen> {
  final _reason = TextEditingController();

  int _chosen = 0;

  LatLng? _proposed;

  bool _busy = false;
  String? _error;

  bool _sent = false;

  StopToFix get _stop => widget.stops[_chosen];

  @override
  void dispose() {
    _reason.dispose();
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
              title: t('stopfix.title'),
              trailing: ChildPill(
                name: widget.child.name,
                line: widget.child.className,
                tint: tint,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 28),
                child: _sent ? _Receipt(tint: tint) : _form(tint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(Color tint) {
    final stop = _stop;
    final moved = stop.at == null || _proposed == null
        ? null
        : _metresBetween(stop.at!, _proposed!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Explainer(tint: tint),
        const SizedBox(height: kCardGap),

        if (widget.stops.length > 1) ...[
          _Label(t('stopfix.whichStop')),
          const SizedBox(height: 7),
          Row(
            children: [
              for (var i = 0; i < widget.stops.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _LegChoice(
                    label: widget.stops[i].pickup
                        ? t('stopfix.pickup')
                        : t('stopfix.dropoff'),
                    stopName: widget.stops[i].name,
                    selected: i == _chosen,
                    tint: tint,
                    onTap: () => setState(() {
                      _chosen = i;
                      _proposed = null;
                    }),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
        ],

        _Label(t('stopfix.currentStop')),
        const SizedBox(height: 7),
        Card16(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_pin_circle_outlined, size: 20, color: tint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    if ((stop.landmark ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        stop.landmark!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                    if (stop.at == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        t('stopfix.noPinOnMap'),
                        style: TextStyle(fontSize: 12, color: AppTheme.textFaint),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _Label(t('stopfix.markTitle')),
        const SizedBox(height: 4),
        Text(
          t('stopfix.markOptional'),
          style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 8),
        _PinPreview(
          current: stop.at,
          proposed: _proposed,
          tint: tint,
          onTap: _pickPin,
        ),
        if (_proposed != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 15, color: AppTheme.textMuted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  moved == null
                      ? t('stopfix.placeMarked')
                      : tn('stopfix.movedBy', moved),
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _proposed = null),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(t('stopfix.removePin')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),

        _Label(t('stopfix.reason')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final k in const [
              'stopfix.quickWrongSide',
              'stopfix.quickTooFar',
              'stopfix.quickUnsafe',
              'stopfix.quickElsewhere',
            ])
              _ReasonChip(
                label: t(k),
                tint: tint,
                onTap: () => _useSuggestion(t(k)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: TextField(
            controller: _reason,
            maxLines: 5,
            minLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14.5, height: 1.4),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: t('stopfix.reasonHint'),
              hintStyle: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textFaint),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.rose,
            ),
          ),
        ],

        const SizedBox(height: 16),
        BigButton(
          label: t('stopfix.send'),
          color: tint,
          height: 52,
          busy: _busy,
          onPressed: _send,
        ),
        const SizedBox(height: 10),
        Text(
          t('stopfix.sendFoot'),
          style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textFaint),
        ),
      ],
    );
  }

  void _useSuggestion(String phrase) {
    final typed = _reason.text.trim();
    setState(() {
      _error = null;
      _reason.text = typed.isEmpty ? phrase : '$typed $phrase';
      _reason.selection = TextSelection.collapsed(offset: _reason.text.length);
    });
  }

  Future<void> _pickPin() async {
    final stop = _stop;
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _PinPicker(
          start: _proposed ?? stop.at,
          current: stop.at,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _proposed = picked);
  }

  Future<void> _send() async {
    final reason = _reason.text.trim();
    if (reason.length < 4) {
      setState(() => _error = t('stopfix.reasonShort'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentApi.instance.submitStopCorrection(
        stopId: _stop.id,
        reason: reason,
        proposedLat: _proposed?.latitude,
        proposedLon: _proposed?.longitude,
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

int _metresBetween(LatLng a, LatLng b) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return (2 * r * math.asin(math.min(1, math.sqrt(h)))).round();
}

class _Explainer extends StatelessWidget {
  const _Explainer({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: AppTheme.dark ? 0.22 : 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.assignment_late_outlined, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('stopfix.explainTitle'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  t('stopfix.explainBody'),
                  style: TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppTheme.green.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_read_outlined, size: 30, color: AppTheme.green),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            t('stopfix.sentTitle'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppTheme.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            t('stopfix.sentBody'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: StatusChip(t('stopfix.underReview'), color: AppTheme.amber)),
        const SizedBox(height: 22),
        Card16(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_in_talk_rounded, size: 17, color: AppTheme.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('stopfix.sentUrgent'),
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        BigButton(
          label: t('common.close'),
          color: tint,
          height: 52,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _PinPreview extends StatelessWidget {
  const _PinPreview({
    required this.current,
    required this.proposed,
    required this.tint,
    required this.onTap,
  });

  final LatLng? current;
  final LatLng? proposed;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!MapTiles.configured) {
      return Card16(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadius),
          child: SizedBox(height: 170, child: MapNotConfigured(tint: tint)),
        ),
      );
    }

    final points = <LatLng>[?current, ?proposed];
    final centre = proposed ?? current ?? _erbil;

    return Card16(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: SizedBox(
          height: 200,
          child: Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  key: ValueKey('${centre.latitude},${centre.longitude},${points.length}'),
                  options: MapOptions(
                    initialCenter: centre,
                    initialZoom: points.isEmpty
                        ? _regionZoom
                        : points.length > 1
                            ? 15.5
                            : 16.5,
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.fromLTRB(56, 56, 56, 56),
                            maxZoom: 17,
                          )
                        : null,
                    minZoom: 4,
                    maxZoom: 18,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none),
                    onTap: (_, _) => onTap(),
                  ),
                  children: [
                    MapTiles.layer(),
                    if (current != null && proposed != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [current!, proposed!],
                            strokeWidth: 2.5,
                            pattern: const StrokePattern.dotted(),
                            color: tint.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (current != null)
                          Marker(
                            point: current!,
                            width: 28,
                            height: 28,
                            child: _Dot(
                              colour: AppTheme.textMuted,
                              icon: Icons.person_pin_circle_outlined,
                            ),
                          ),
                        if (proposed != null)
                          Marker(
                            point: proposed!,
                            width: 32,
                            height: 32,
                            child: _Dot(colour: tint, icon: Icons.push_pin_rounded),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              PositionedDirectional(
                start: 10,
                top: 10,
                child: _Legend(current: current != null, proposed: proposed != null, tint: tint),
              ),

              PositionedDirectional(
                end: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_location_alt_rounded, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        proposed == null ? t('stopfix.placePin') : t('stopfix.movePin'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const MapOffline(),
              PositionedDirectional(start: 8, bottom: 6, child: const MapAttribution()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.current, required this.proposed, required this.tint});

  final bool current;
  final bool proposed;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (!current && !proposed) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x14101828), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current) _line(AppTheme.textMuted, t('stopfix.legendNow')),
          if (current && proposed) const SizedBox(height: 4),
          if (proposed) _line(tint, t('stopfix.legendYours')),
        ],
      ),
    );
  }

  Widget _line(Color colour, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.text),
          ),
        ],
      );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.colour, required this.icon});

  final Color colour;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colour, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 14, color: colour),
      );
}

const _erbil = LatLng(36.1901, 44.0091);

const _stopZoom = 17.5;

const _regionZoom = 7.0;

const _streetZoom = 16.0;

class _PinPicker extends StatefulWidget {
  const _PinPicker({required this.start, required this.current});

  final LatLng? start;

  final LatLng? current;

  @override
  State<_PinPicker> createState() => _PinPickerState();
}

class _PinPickerState extends State<_PinPicker> {
  late final LatLng? _anchor = widget.start ?? widget.current;

  late LatLng _at = _anchor ?? _erbil;
  late double _zoom = _anchor != null ? _stopZoom : _regionZoom;

  bool _panned = false;

  bool get _canUse => (_anchor != null || _panned) && _zoom >= _streetZoom;

  String get _hint => _anchor == null && !_panned
      ? t('stopfix.startNotYours')
      : t('stopfix.zoomIn');

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final moved = widget.current == null ? null : _metresBetween(widget.current!, _at);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('stopfix.markTitle')),
            Expanded(
              child: !MapTiles.configured
                  ? MapNotConfigured(tint: tint)
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: _at,
                              initialZoom: _zoom,
                              minZoom: 4,
                              maxZoom: 19,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.pinchZoom |
                                    InteractiveFlag.drag |
                                    InteractiveFlag.doubleTapZoom,
                              ),
                              onPositionChanged: (camera, hasGesture) {
                                if (!hasGesture) return;
                                setState(() {
                                  _panned = _panned ||
                                      camera.center.latitude != _at.latitude ||
                                      camera.center.longitude != _at.longitude;
                                  _at = camera.center;
                                  _zoom = camera.zoom;
                                });
                              },
                            ),
                            children: [
                              MapTiles.layer(),
                              if (widget.current != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: widget.current!,
                                      width: 28,
                                      height: 28,
                                      child: _Dot(
                                        colour: AppTheme.textMuted,
                                        icon: Icons.person_pin_circle_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        IgnorePointer(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 34),
                              child: Icon(
                                Icons.location_on,
                                size: 40,
                                color: tint,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x55000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        PositionedDirectional(
                          start: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppTheme.surface.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Text(
                              moved == null
                                  ? t('stopfix.dragHere')
                                  : tn('stopfix.movedBy', moved),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                          ),
                        ),

                        const MapOffline(),
                        PositionedDirectional(
                          start: 8,
                          bottom: 6,
                          child: const MapAttribution(),
                        ),
                      ],
                    ),
            ),
            if (MapTiles.configured) ...[
              if (!_canUse)
                Padding(
                  padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.textFaint),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _hint,
                          style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(kGutter, 10, kGutter, 14),
                child: BigButton(
                  label: t('stopfix.usePlace'),
                  color: tint,
                  height: 52,
                  onPressed: _canUse ? () => Navigator.of(context).pop(_at) : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegChoice extends StatelessWidget {
  const _LegChoice({
    required this.label,
    required this.stopName,
    required this.selected,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final String stopName;
  final bool selected;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.09)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? tint : AppTheme.border, width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: selected ? tint : AppTheme.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stopName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label, required this.tint, required this.onTap});

  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: AppTheme.dark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: tint),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tint),
            ),
          ],
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
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: AppTheme.textMuted,
        ),
      );
}
