import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../ui/map_tiles.dart';

/// The shape a bus actually drives between its stops.
///
/// The run used to be drawn as straight lines from stop to stop. On a map that
/// reads as a road the bus does not take — through the Citadel, across blocks
/// with no through route — and a driver checking the order of two stops against
/// the picture is being shown something untrue about their own route. It also
/// makes the run look shorter than it is.
///
/// Mapbox Directions turns the stops into the driving line between them. The
/// same public token that fetches the tiles fetches this; it is designed to
/// ship inside a client.
///
/// Everything here fails soft. No token, no signal, a refused quota, a stop in
/// the sea — all of them return the straight line rather than an error, because
/// a driver who is late needs a diagram of the order more than a perfect one,
/// and an empty map tells them nothing at all.
class Directions {
  Directions._();

  /// Shapes already fetched this session, keyed by the exact list of points.
  ///
  /// The map rebuilds on every tap, every camera move and every tick of the
  /// run; without this the same six stops would be re-fetched dozens of times
  /// in a morning and the driver would pay for it in both quota and data.
  static final Map<String, List<LatLng>> _cache = {};

  /// In-flight requests, so a rebuild during the round trip joins the existing
  /// one instead of starting a second.
  static final Map<String, Future<List<LatLng>>> _running = {};

  /// The most waypoints Mapbox will take in one driving request.
  static const _maxPerRequest = 25;

  static String _key(List<LatLng> stops) =>
      stops.map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}').join(';');

  /// The driving line through [stops], or the straight line if it cannot be had.
  ///
  /// Fewer than two stops is not a route, and is returned unchanged.
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

  /// Whatever has already been fetched for these stops, without waiting.
  ///
  /// Lets the map paint the straight line immediately and swap in the road when
  /// it arrives, rather than showing nothing until the network answers.
  static List<LatLng>? cached(List<LatLng> stops) => _cache[_key(stops)];

  static Future<List<LatLng>> _fetch(List<LatLng> stops) async {
    // Over 25 stops the run is split, and each leg after the first starts on
    // the stop the previous one ended at so the pieces join without a gap.
    final legs = <List<LatLng>>[];
    for (var i = 0; i < stops.length - 1; i += _maxPerRequest - 1) {
      final end = (i + _maxPerRequest).clamp(0, stops.length);
      legs.add(stops.sublist(i, end));
      if (end == stops.length) break;
    }

    final out = <LatLng>[];
    for (final leg in legs) {
      final line = await _leg(leg);
      // The joining stop belongs to both legs; keep it once.
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

    // Short: the line is an improvement on a picture that already works, so it
    // must never be the reason a map takes ten seconds to appear.
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

  /// Split a road line at the point nearest [at].
  ///
  /// The run is drawn in two colours — the part already driven and the part
  /// still owed — and the join has to sit on the road rather than at the stop's
  /// own coordinate, which is usually a few metres off the carriageway.
  static int nearestIndex(List<LatLng> line, LatLng at) {
    var best = 0;
    var bestGap = double.infinity;
    for (var i = 0; i < line.length; i++) {
      final dLat = line[i].latitude - at.latitude;
      final dLon = line[i].longitude - at.longitude;
      // Squared degrees. Comparing, not measuring, so the cost of a real
      // distance is not worth paying once per point per rebuild.
      final gap = dLat * dLat + dLon * dLon;
      if (gap < bestGap) {
        bestGap = gap;
        best = i;
      }
    }
    return best;
  }
}
