import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// latlong2 exports a generic Path<T>, which shadows dart:ui's Path.
import 'package:latlong2/latlong.dart' hide Path;

import '../../api/client.dart';
import '../../api/geocode.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/map_tiles.dart';
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

  /// Reverse geocoding, held back until the map stops moving.
  ///
  /// Dragging a map produces a position on every frame. Asking for an address
  /// on each of those would be both useless and, on a shared public geocoder,
  /// rude enough to get the app blocked.
  Timer? _finding;
  bool _looking = false;

  /// The last address this screen wrote into the box by itself.
  ///
  /// Kept so a parent's own words are never overwritten. Once they have typed
  /// something, the pin stops filling the field and only their edit stands —
  /// the point of the box is the part a map cannot know, like which door.
  String? _autoFilled;

  /// Nothing on this screen moves until Edit is pressed.
  ///
  /// The map is full-bleed in the middle of a scrolling form, so trying to
  /// scroll past it dragged the pin instead — and the pin is what the office
  /// reads to decide which stop a child rides from. It moved silently, and Save
  /// could not tell an accident from an intention.
  bool _editing = false;

  /// What was on screen when editing started, to put back on Cancel.
  String _wasAddress = '';
  String _wasNote = '';
  LatLng? _wasPin;

  bool _busy = false;
  bool _dirty = false;
  String? _error;

  /// Erbil, so a family with nothing on file starts somewhere they recognise
  /// rather than in the Atlantic.
  static const _fallback = LatLng(36.1901, 44.0091);

  @override
  void dispose() {
    _finding?.cancel();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _wasAddress = _address.text;
      _wasNote = _note.text;
      _wasPin = _pin;
    });
  }

  /// Put everything back the way it was found.
  void _cancelEditing() {
    _finding?.cancel();
    setState(() {
      _editing = false;
      _looking = false;
      _address.text = _wasAddress;
      _note.text = _wasNote;
      _pin = _wasPin;
      _dirty = false;
      _error = null;
    });
    if (_wasPin != null) _map.move(_wasPin!, _map.camera.zoom);
  }

  /// Ask for the address once the map has been still for a moment.
  void _scheduleLookUp(LatLng at) {
    _finding?.cancel();
    // force: the parent moved the pin. That is an instruction to re-read the
    // address, not a suggestion to fill it in if it happens to be empty.
    _finding = Timer(const Duration(milliseconds: 900), () => _lookUp(at, force: true));
  }

  /// Fill the box in from the pin, without ever taking words off a parent.
  ///
  /// The box is only written to while it is empty or still holds exactly what
  /// this screen last put there. The moment somebody types their own — which is
  /// the whole point of the field, since a map does not know which door or
  /// which floor — the pin stops touching it.
  Future<void> _lookUp(LatLng at, {bool force = false}) async {
    // Without force, only an empty box — or one still holding exactly what this
    // screen last wrote — is touched. That is the quiet fill on open, and it
    // must never talk over words somebody typed.
    //
    // With force, the pin has just been dragged, in edit mode, on purpose. The
    // address that belongs to the old position is no longer the answer to
    // anything, so it is replaced. This is the whole reason the box and the map
    // are on the same screen.
    if (!force) {
      final typed = _address.text.trim();
      if (typed.isNotEmpty && typed != _autoFilled) return;
    }

    if (mounted) setState(() => _looking = true);
    final found = await Geocode.at(at.latitude, at.longitude);
    if (!mounted) return;

    setState(() {
      _looking = false;
      if (found == null) return;
      if (!force) {
        // The parent may have started typing while we were asking.
        final now = _address.text.trim();
        if (now.isNotEmpty && now != _autoFilled) return;
      }
      _address.text = found;
      _autoFilled = found;
      _dirty = true;
    });
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

                    // A pin already saved, but no words against it — which is
                    // every family who dropped the pin before this existed.
                    if (_pin != null && _address.text.trim().isEmpty) {
                      _lookUp(_pin!);
                    }
                  }
                  return h;
                },
                builder: (context, home) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Explainer(tint: tint),
                    const SizedBox(height: kCardGap),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _editing ? t(_pin == null ? 'home.dragToPlace' : 'home.dragToAdjust') : t('home.locked'),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _EditToggle(
                          editing: _editing,
                          tint: tint,
                          onTap: _editing ? _cancelEditing : _startEditing,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    _MapCard(
                      pin: _pin ?? _fallback,
                      placed: _pin != null,
                      enabled: _editing,
                      controller: _map,
                      tint: tint,
                      onMoved: (c) {
                        setState(() {
                          _pin = c;
                          _dirty = true;
                        });
                        _scheduleLookUp(c);
                      },
                    ),
                    const SizedBox(height: kCardGap),

                    Row(
                      children: [
                        _Label(t('home.address')),
                        if (_looking) ...[
                          const SizedBox(width: 9),
                          SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(strokeWidth: 1.6, color: tint),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            t('home.findingAddress'),
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    _Box(
                      child: TextField(
                        controller: _address,
                        readOnly: !_editing,
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
                        readOnly: !_editing,
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

                    if (_editing) ...[
                      const SizedBox(height: 16),
                      BigButton(
                        label: t('home.save'),
                        color: tint,
                        height: 52,
                        busy: _busy,
                        onPressed: _save,
                      ),
                    ],

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
/// Edit, and then Cancel. Small, because it sits beside a line of guidance
/// rather than under it.
class _EditToggle extends StatelessWidget {
  const _EditToggle({required this.editing, required this.tint, required this.onTap});

  final bool editing;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = editing ? AppTheme.textMuted : tint;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: editing ? Colors.transparent : tint.withValues(alpha: AppTheme.dark ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: editing ? AppTheme.border : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(editing ? Icons.close_rounded : Icons.edit_rounded, size: 15, color: colour),
            const SizedBox(width: 7),
            Text(
              editing ? t('common.cancel') : t('common.edit'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colour),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.pin,
    required this.placed,
    required this.enabled,
    required this.controller,
    required this.tint,
    required this.onMoved,
  });

  final LatLng pin;
  final bool placed;

  /// Whether a finger on this map moves the pin or scrolls the page past it.
  final bool enabled;
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
                  // Nothing until Edit. Otherwise a finger meant for the page
                  // drags the pin, silently, and the page does not scroll.
                  interactionOptions: InteractionOptions(
                    flags: enabled
                        ? InteractiveFlag.pinchZoom |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom
                        : InteractiveFlag.none,
                  ),
                  // The pin IS the centre. Reported as the map settles rather
                  // than on every frame of a drag.
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) onMoved(camera.center);
                  },
                ),
                children: [
                  MapTiles.layer(),
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

              // Mapbox's licence requires the credit.
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
                    MapTiles.credit,
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
