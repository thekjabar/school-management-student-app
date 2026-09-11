import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

  LatLng? _pin;

  Timer? _finding;
  bool _looking = false;

  String? _autoFilled;

  bool _editing = false;

  String _wasAddress = '';
  String _wasNote = '';
  LatLng? _wasPin;

  bool _busy = false;
  bool _dirty = false;
  String? _error;

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

  void _goTo(Place p) {
    final at = LatLng(p.lat, p.lon);
    setState(() {
      _pin = at;
      _dirty = true;
    });
    _map.move(at, 17);
    _lookUp(at, force: true);
  }

  void _scheduleLookUp(LatLng at) {
    _finding?.cancel();
    _finding = Timer(const Duration(milliseconds: 900), () => _lookUp(at, force: true));
  }

  Future<void> _lookUp(LatLng at, {bool force = false}) async {
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
                  if (!_dirty) {
                    _address.text = h.address ?? '';
                    _note.text = h.note ?? '';
                    _pin = h.hasPin ? LatLng(h.lat!, h.lon!) : null;

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

                    if (_editing) ...[
                      _PlaceSearch(
                        tint: tint,
                        nearLat: (_pin ?? _fallback).latitude,
                        nearLon: (_pin ?? _fallback).longitude,
                        onPicked: _goTo,
                      ),
                      const SizedBox(height: 10),
                    ],

                    _MapCard(
                      key: const ValueKey('home-address-map'),
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
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textFaint),
      );

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final movedPin = _pin != null && (_wasPin == null || _wasPin != _pin);
    try {
      await ParentApi.instance.saveHomeLocation(
        lat: _pin?.latitude,
        lon: _pin?.longitude,
        address: _address.text,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _dirty = false;
        _wasAddress = _address.text;
        _wasNote = _note.text;
        _wasPin = _pin;
      });
      showNote(context, t('home.saved'));
      _loader.currentState?.reload(quiet: true);
      if (movedPin) await _offerToTellTheOffice();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerToTellTheOffice() async {
    if (!mounted) return;

    final ask = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('home.askOfficeTitle')),
        content: Text(t('home.askOfficeBody'), style: const TextStyle(height: 1.55)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('home.askOfficeLater')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('home.askOfficeSend')),
          ),
        ],
      ),
    );
    if (ask != true || !mounted) return;

    try {
      final children = await ParentApi.instance.children();
      final address = _address.text.trim();
      final message = address.isEmpty
          ? t('home.askOfficeMessage')
          : tn('home.askOfficeMessageAt', address);

      var sent = 0;
      for (final child in children) {
        try {
          await ParentApi.instance.raiseConcern(
            studentId: child.studentId,
            urgency: 'QUESTION',
            topic: 'PICKUP_ARRANGEMENT',
            message: message,
          );
          sent++;
        } on ApiException catch (e) {
          debugPrint('home: could not ask about ${child.studentId}: ${e.message}');
        }
      }

      if (!mounted) return;
      showNote(
        context,
        sent == 0 ? t('home.askOfficeFailed') : tn('home.askOfficeSent', sent),
        bad: sent == 0,
      );
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
  }
}

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

class _PlaceSearch extends StatefulWidget {
  const _PlaceSearch({
    required this.tint,
    required this.nearLat,
    required this.nearLon,
    required this.onPicked,
  });

  final Color tint;
  final double nearLat;
  final double nearLon;
  final ValueChanged<Place> onPicked;

  @override
  State<_PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<_PlaceSearch> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _looking = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _typed(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
        _looking = false;
      });
      return;
    }
    setState(() => _looking = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(q));
  }

  Future<void> _run(String q) async {
    final found = await PlaceSearch.suggest(q, nearLat: widget.nearLat, nearLon: widget.nearLon);
    if (!mounted) return;
    if (_field.text.trim() != q.trim()) return;
    setState(() {
      _results = found;
      _looking = false;
      _searched = true;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _field.clear();
    setState(() {
      _results = const [];
      _searched = false;
      _looking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!PlaceSearch.available) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 19, color: AppTheme.textFaint),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _field,
                  focusNode: _focus,
                  onChanged: _typed,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (q) => _run(q),
                  style: const TextStyle(fontSize: 14.5),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: t('home.searchHint'),
                    hintStyle: TextStyle(fontSize: 14, color: AppTheme.textFaint),
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              if (_looking)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_field.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppTheme.textFaint,
                  visualDensity: VisualDensity.compact,
                  onPressed: _clear,
                  tooltip: t('common.clear'),
                ),
            ],
          ),
        ),

        if (_results.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _results.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppTheme.border),
                  InkWell(
                    onTap: () {
                      _focus.unfocus();
                      widget.onPicked(_results[i]);
                      _clear();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          Icon(Icons.place_outlined, size: 18, color: widget.tint),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _results[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                if (_results[i].detail.isNotEmpty)
                                  Text(
                                    _results[i].detail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if (_searched && !_looking) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4),
            child: Text(
              t('home.searchNone'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}

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

class _NoMap extends StatelessWidget {
  const _NoMap({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Card16(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kCardRadius),
          child: SizedBox(
            height: height,
            child: MapNotConfigured(tint: Role.parent.tint),
          ),
        ),
      );
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    super.key,
    required this.pin,
    required this.placed,
    required this.enabled,
    required this.controller,
    required this.tint,
    required this.onMoved,
  });

  final LatLng pin;
  final bool placed;

  final bool enabled;
  final MapController controller;
  final Color tint;
  final ValueChanged<LatLng> onMoved;

  @override
  Widget build(BuildContext context) {
    if (!MapTiles.configured) return const _NoMap(height: 300);
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
                  interactionOptions: InteractionOptions(
                    flags: enabled
                        ? InteractiveFlag.pinchZoom |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom
                        : InteractiveFlag.none,
                  ),
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) onMoved(camera.center);
                  },
                ),
                children: [
                  MapTiles.layer(),
                ],
              ),

              IgnorePointer(
                child: Center(
                  child: Padding(
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

              PositionedDirectional(
                start: 8,
                bottom: 6,
                child: const MapAttribution(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
