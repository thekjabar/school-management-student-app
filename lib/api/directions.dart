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
