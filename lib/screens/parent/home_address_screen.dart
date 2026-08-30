import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 exports a generic Path<T>, which shadows dart:ui's Path.
import 'package:latlong2/latlong.dart' hide Path;

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';

/// Where the family lives, told to the school by the family.
///
/// Until now nobody could say. The address on file was whatever somebody typed
/// at enrolment, and when a family moved house the school found out because a
/// child was standing at the wrong corner.
///
/// TWO THINGS THIS SCREEN IS CAREFUL ABOUT, and both are about not promising
/// more than the platform does.
///
/// Dropping a pin does NOT move a bus stop. A route is planned, sequenced and
/// timed; a family that could move a stop by dragging would break the run for
/// every other child on it. The office reads this and decides which stop each
/// child uses — so the screen says that plainly, and shows the stops currently
/// assigned underneath, which is the honest answer to "did that do anything".
///
/// The WRITTEN NOTE outranks the pin. Addressing here is landmark-based rather
/// than street-based: "the blue gate opposite the bakery, second turning after
/// the mosque" is how a driver actually finds somebody, and coordinates are for
/// the planner. So the note is a full-width field with a real example in it,
/// not an afterthought under the map.
class HomeAddressScreen extends StatefulWidget {
  const HomeAddressScreen({super.key});

  @override
  State<HomeAddressScreen> createState() => _HomeAddressScreenState();
}

class _HomeAddressScreenState extends State<HomeAddressScreen> {
  final _loader = GlobalKey<LoaderState<HomeLocation>>();
  final _map = MapController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  /// Where the pin is now. The map moves under a fixed centre marker rather
  /// than the marker being dragged: on a phone a dragged pin spends most of
  /// its time under the thumb that is dragging it.
  LatLng? _pin;

  bool _busy = false;
  bool _dirty = false;
  String? _error;

  /// Erbil, so a family with nothing on file starts somewhere they recognise
  /// rather than in the Atlantic.
  static const _fallback = LatLng(36.1901, 44.0091);

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
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
            ScreenHeader(title: t('home.title')),
            Expanded(
              child: Loader<HomeLocation>(
                key: _loader,
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 28),
                load: () async {
                  final h = await ParentApi.instance.homeLocation();
                  // Only on the FIRST load. Refilling these after a save would
                  // wipe an edit somebody is halfway through typing.
                  if (!_dirty) {
                    _address.text = h.address ?? '';
                    _note.text = h.note ?? '';
                    _pin = h.hasPin ? LatLng(h.lat!, h.lon!) : null;
                  }
                  return h;
                },
                builder: (context, home) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Explainer(tint: tint),
                    const SizedBox(height: kCardGap),
                    _MapCard(
                      pin: _pin ?? _fallback,
                      placed: _pin != null,
                      controller: _map,
                      tint: tint,
                      onMoved: (c) => setState(() {
                        _pin = c;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: kCardGap),

                    _Label(t('home.address')),
                    const SizedBox(height: 7),
                    _Box(
                      child: TextField(
                        controller: _address,
                        maxLength: 400,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _plain(t('home.addressHint')),
                        style: _entry,
                        onChanged: (_) => _dirty = true,
                      ),
                    ),

                    const SizedBox(height: 14),
                    _Label(t('home.note')),
                    const SizedBox(height: 4),
                    Text(
                      t('home.noteWhy'),
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 7),
                    _Box(
                      child: TextField(
                        controller: _note,
                        maxLines: 4,
                        minLines: 3,
                        maxLength: 600,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _plain(t('home.noteHint')),
                        style: _entry,
                        onChanged: (_) => _dirty = true,
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
                      label: t('home.save'),
                      color: tint,
                      height: 52,
                      busy: _busy,
                      onPressed: _save,
                    ),

                    if (home.children.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionRow(title: t('home.stopsNow')),
                      const SizedBox(height: 4),
                      for (final c in home.children) ...[
                        _ChildStops(child: c, tint: tint),
                        const SizedBox(height: kCardGap),
                      ],
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

  static const _entry = TextStyle(fontSize: 14.5, height: 1.4);

  InputDecoration _plain(String hint) => InputDecoration(
        border: InputBorder.none,
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textFaint),
      );

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentApi.instance.saveHomeLocation(
        lat: _pin?.latitude,
        lon: _pin?.longitude,
        address: _address.text,
        note: _note.text,
      );
      if (!mounted) return;
      _dirty = false;
      showNote(context, t('home.saved'));
      _loader.currentState?.reload(quiet: true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// What this does, and what it does not.
class _Explainer extends StatelessWidget {
  const _Explainer({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
            child: Icon(Icons.home_outlined, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('home.explainTitle'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  t('home.explainBody'),
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

/// The map, with a pin fixed at the centre and the map moving under it.
class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.pin,
    required this.placed,
    required this.controller,
    required this.tint,
    required this.onMoved,
  });

  final LatLng pin;
  final bool placed;
  final MapController controller;
  final Color tint;
  final ValueChanged<LatLng> onMoved;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kCardRadius),
        child: SizedBox(
          height: 300,
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: pin,
                  initialZoom: placed ? 17 : 13,
                  minZoom: 4,
                  maxZoom: 19,
                  // No rotation. North stays up so the streets match the ones
                  // in somebody's head.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.doubleTapZoom,
                  ),
                  // The pin IS the centre. Reported as the map settles rather
                  // than on every frame of a drag.
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) onMoved(camera.center);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.kurdistanstudentprotection.ksp',
                    maxNativeZoom: 19,
                  ),
                ],
              ),

              // Drawn OVER the map at dead centre, not as a marker on it: a pin
              // you drag with a finger spends the whole drag underneath that
              // finger, which is the one moment you need to see where it is.
              IgnorePointer(
                child: Center(
                  child: Padding(
                    // Lifted by half its own height so the point sits on the
                    // centre rather than the middle of the teardrop.
                    padding: const EdgeInsets.only(bottom: 34),
                    child: Icon(
                      Icons.location_on,
                      size: 40,
                      color: placed ? tint : AppTheme.textMuted,
                      shadows: const [
                        Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                ),
              ),

              PositionedDirectional(
                start: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    placed ? t('home.dragToAdjust') : t('home.dragToPlace'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.text,
                    ),
                  ),
                ),
              ),

              // OpenStreetMap's licence requires the credit.
              PositionedDirectional(
                start: 8,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The stops one child actually rides between — what the address led to.
class _ChildStops extends StatelessWidget {
  const _ChildStops({required this.child, required this.tint});

  final AssignedStops child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            child.name,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppTheme.text,
            ),
          ),
          const SizedBox(height: 9),
          _StopLine(
            icon: Icons.arrow_upward_rounded,
            label: t('home.pickedUpAt'),
            stop: child.pickup,
            colour: AppTheme.green,
          ),
          const SizedBox(height: 8),
          _StopLine(
            icon: Icons.arrow_downward_rounded,
            label: t('home.droppedAt'),
            stop: child.dropoff,
            colour: tint,
          ),
        ],
      ),
    );
  }
}

class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.icon,
    required this.label,
    required this.stop,
    required this.colour,
  });

  final IconData icon;
  final String label;
  final StopPoint? stop;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: stop == null ? AppTheme.textFaint : colour),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                // No stop yet is a real state, not an error: a child can be
                // enrolled before the office has placed them on a route.
                stop?.name ?? t('home.noStopYet'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: stop == null ? AppTheme.textMuted : AppTheme.text,
                ),
              ),
              if (stop?.landmark != null && stop!.landmark!.isNotEmpty)
                Text(
                  stop!.landmark!,
                  style: TextStyle(fontSize: 12.5, height: 1.35, color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
      ],
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

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: child,
      );
}
