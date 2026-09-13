import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../ui/map_tiles.dart';

class Directions {
  Directions._();

  static final Map<String, List<LatLng>> _cache = {};

  static final Map<String, Future<List<LatLng>>> _running = {};

  static const _maxPerRequest = 25;

  static String _key(List<LatLng> stops) =>
      stops.map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}').join(';');

  static Future<List<LatLng>> road(List<LatLng> stops) {
    if (stops.length < 2 || !MapTiles.configured) return Future.value(stops);
    final key = _key(stops);
    final cached = _cache[key];
    if (cached != null) return Future.value(cached);
    return _running[key] ??= _fetch(stops).then((line) {
      _cache[key] = line;
      _running.remove(key);
      return line;
    }).catchError((Object _) {
      _running.remove(key);
      return stops;
    });
  }

  static List<LatLng>? cached(List<LatLng> stops) => _cache[_key(stops)];

  static Future<List<LatLng>> _fetch(List<LatLng> stops) async {
    final legs = <List<LatLng>>[];
    for (var i = 0; i < stops.length - 1; i += _maxPerRequest - 1) {
      final end = (i + _maxPerRequest).clamp(0, stops.length);
      legs.add(stops.sublist(i, end));
      if (end == stops.length) break;
    }

    final out = <LatLng>[];
    for (final leg in legs) {
      final line = await _leg(leg);
      out.addAll(out.isEmpty ? line : line.skip(1));
    }
    return out.isEmpty ? stops : out;
  }

  static Future<List<LatLng>> _leg(List<LatLng> leg) async {
    final coords = leg.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
      '?geometries=geojson&overview=full&access_token=${MapTiles.token}',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return leg;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) return leg;
    final geometry = (routes.first as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
    final line = geometry?['coordinates'] as List?;
    if (line == null || line.length < 2) return leg;

    return [
      for (final pair in line)
        LatLng(
          ((pair as List)[1] as num).toDouble(),
          (pair[0] as num).toDouble(),
        ),
    ];
  }

  static final Map<String, List<List<LatLng>>> _runCache = {};

  static final Map<String, Future<List<List<LatLng>>?>> _runRunning = {};

  static const double _stopSnapMetres = 150;

  static const double _schoolSnapMetres = 250;

  static List<List<LatLng>>? cachedRun(List<LatLng> points, {double? startBearing, int? schoolIndex}) =>
      _runCache[_runKey(points, startBearing, schoolIndex)];

  static String _runKey(List<LatLng> points, double? startBearing, int? schoolIndex) =>
      '${_key(points)}|${startBearing == null ? '' : (startBearing / 15).round()}|${schoolIndex ?? ''}';

  static Future<List<List<LatLng>>?> runLegs(
    List<LatLng> points, {
    double? startBearing,
    int? schoolIndex,
  }) {
    if (points.length < 2 || !MapTiles.configured) return Future.value(null);
    final key = _runKey(points, startBearing, schoolIndex);
    final cached = _runCache[key];
    if (cached != null) return Future.value(cached);
    return _runRunning[key] ??= _fetchRun(points, startBearing, schoolIndex).then((legs) {
      _runRunning.remove(key);
      if (legs != null) _runCache[key] = legs;
      return legs;
    }).catchError((Object _) {
      _runRunning.remove(key);
      return null;
    });
  }

  static Future<List<List<LatLng>>?> _fetchRun(
    List<LatLng> points,
    double? startBearing,
    int? schoolIndex,
  ) async {
    final legs = <List<LatLng>>[];
    for (var i = 0; i < points.length - 1; i += _maxPerRequest - 1) {
      final end = (i + _maxPerRequest).clamp(0, points.length);
      final window = points.sublist(i, end);
      final part = await _runWindow(
        window,
        startBearing: i == 0 ? startBearing : null,
        schoolAt: schoolIndex == null ? null : schoolIndex - i,
      );
      if (part == null || part.length != window.length - 1) return null;
      legs.addAll(part);
      if (end == points.length) break;
    }
    return trimSpurs(legs);
  }

  static Future<List<List<LatLng>>?> _runWindow(
    List<LatLng> window, {
    double? startBearing,
    int? schoolAt,
  }) async {
    final snapped = await _runRequest(window, startBearing: startBearing, schoolAt: schoolAt, snap: true);
    if (snapped != null) return snapped;
    return _runRequest(window, startBearing: startBearing, schoolAt: schoolAt, snap: false);
  }

  static Future<List<List<LatLng>>?> _runRequest(
    List<LatLng> window, {
    required double? startBearing,
    required int? schoolAt,
    required bool snap,
  }) async {
    final coords = window.map((p) => '${p.longitude},${p.latitude}').join(';');
    final approaches = [
      for (var i = 0; i < window.length; i++) i == schoolAt ? 'curb' : 'unrestricted',
    ].join(';');
    final radiuses = [
      for (var i = 0; i < window.length; i++)
        i == 0
            ? 'unlimited'
            : i == schoolAt
                ? '${_schoolSnapMetres.round()}'
                : '${_stopSnapMetres.round()}',
    ].join(';');
    final bearings = startBearing == null
        ? null
        : [
            for (var i = 0; i < window.length; i++) i == 0 ? '${startBearing.round() % 360},60' : '',
          ].join(';');

    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/$coords'
      '?geometries=polyline6&overview=full&steps=true&continue_straight=false'
      '&approaches=$approaches'
      '${snap ? '&radiuses=$radiuses' : ''}'
      '${bearings == null ? '' : '&bearings=$bearings'}'
      '&access_token=${MapTiles.token}',
    );

    final res = await http.get(url).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') return null;
    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final legs = (route['legs'] as List?) ?? const [];
    if (legs.length != window.length - 1) return null;

    final out = <List<LatLng>>[];
    for (final leg in legs) {
      final steps = ((leg as Map<String, dynamic>)['steps'] as List?) ?? const [];
      final line = <LatLng>[];
      for (final step in steps) {
        final geometry = (step as Map<String, dynamic>)['geometry'];
        if (geometry is! String) continue;
        final part = decodePolyline6(geometry);
        line.addAll(line.isEmpty ? part : part.skip(1));
      }
      if (line.length < 2) {
        if (legs.length == 1 && route['geometry'] is String) {
          line
            ..clear()
            ..addAll(decodePolyline6(route['geometry'] as String));
        }
      }
      if (line.length < 2) return null;
      out.add(line);
    }
    return out;
  }

  static List<LatLng> decodePolyline6(String encoded) {
    final out = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lon = 0;
    while (index < encoded.length) {
      final dLat = _nextValue(encoded, index);
      if (dLat.$2 > encoded.length) break;
      final dLon = _nextValue(encoded, dLat.$2);
      if (dLon.$2 > encoded.length) break;
      index = dLon.$2;
      lat += dLat.$1;
      lon += dLon.$1;
      out.add(LatLng(lat / 1e6, lon / 1e6));
    }
    return out;
  }

  static (int, int) _nextValue(String encoded, int start) {
    var index = start;
    var result = 0;
    var shift = 0;
    int byte;
    do {
      if (index >= encoded.length) return (0, encoded.length + 1);
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return ((result & 1) != 0 ? ~(result >> 1) : (result >> 1), index);
  }

  static const double _spurToleranceMetres = 4;

  static List<List<LatLng>> trimSpurs(List<List<LatLng>> legs) {
    final out = [for (final leg in legs) List<LatLng>.of(leg)];
    for (var i = 0; i < out.length - 1; i++) {
      final a = out[i];
      final b = out[i + 1];
      var k = 0;
      while (a.length - k > 2 &&
          b.length - k > 2 &&
          _gapMetres(a[a.length - 2 - k], b[1 + k]) <= _spurToleranceMetres) {
        k++;
      }
      if (k == 0) continue;
      out[i] = a.sublist(0, a.length - k);
      out[i + 1] = b.sublist(k);
    }
    return out;
  }

  static double _gapMetres(LatLng a, LatLng b) =>
      const Distance(roundResult: false, calculator: Haversine()).as(LengthUnit.Meter, a, b);

  static final Map<String, double> _seconds = {};

  static final Map<String, double> _metres = {};

  static final Map<String, Future<bool>> _matrixRunning = {};

  static const _maxMatrix = 25;

  static String _pair(LatLng a, LatLng b) => '${_key([a])}>${_key([b])}';

  static double? seconds(LatLng from, LatLng to) => _seconds[_pair(from, to)];

  static double? metres(LatLng from, LatLng to) => _metres[_pair(from, to)];

  static Future<bool> travelTimes(List<LatLng> points, {bool fromFirstOnly = false}) {
    if (points.length < 2 || points.length > _maxMatrix || !MapTiles.configured) {
      return Future.value(false);
    }
    final known = fromFirstOnly
        ? points.skip(1).every((p) => _seconds.containsKey(_pair(points.first, p)))
        : points.every((a) => points.every((b) => identical(a, b) || _seconds.containsKey(_pair(a, b))));
    if (known) return Future.value(true);

    final key = '${fromFirstOnly ? 'row' : 'all'}|${_key(points)}';
    return _matrixRunning[key] ??= _fetchMatrix(points, fromFirstOnly).then((ok) {
      _matrixRunning.remove(key);
      return ok;
    }).catchError((Object _) {
      _matrixRunning.remove(key);
      return false;
    });
  }

  static Future<bool> _fetchMatrix(List<LatLng> points, bool fromFirstOnly) async {
    final coords = points.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = Uri.parse(
      'https://api.mapbox.com/directions-matrix/v1/mapbox/driving/$coords'
      '?annotations=duration,distance'
      '${fromFirstOnly ? '&sources=0' : ''}'
      '&access_token=${MapTiles.token}',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok') return false;
    final durations = body['durations'] as List?;
    final distances = body['distances'] as List?;
    if (durations == null) return false;

    var filled = 0;
    for (var row = 0; row < durations.length; row++) {
      final from = points[row];
      final cells = durations[row] as List;
      final lengths = distances == null ? null : distances[row] as List;
      for (var col = 0; col < cells.length && col < points.length; col++) {
        final value = cells[col];
        if (value is! num) continue;
        _seconds[_pair(from, points[col])] = value.toDouble();
        final length = lengths?[col];
        if (length is num) _metres[_pair(from, points[col])] = length.toDouble();
        filled++;
      }
    }
    return filled > 0;
  }

  static int nearestIndex(List<LatLng> line, LatLng at) {
    var best = 0;
    var bestGap = double.infinity;
    for (var i = 0; i < line.length; i++) {
      final dLat = line[i].latitude - at.latitude;
      final dLon = line[i].longitude - at.longitude;
      final gap = dLat * dLat + dLon * dLon;
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    return best;
  }
}
