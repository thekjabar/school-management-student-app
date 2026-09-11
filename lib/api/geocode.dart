import 'dart:convert';

import 'package:http/http.dart' as http;

import '../i18n/strings.dart';
import '../ui/map_tiles.dart';

class Place {
  const Place({required this.name, required this.detail, required this.lat, required this.lon});

  final String name;

  final String detail;

  final double lat;
  final double lon;
}

class PlaceSearch {
  PlaceSearch._();

  static const _agent = 'KSP-Parent/1.0 (Kurdistan Student Protection; school transport)';

  static bool get available => true;

  static String get _language => switch (AppLocale.current.value) {
        Lang.ar => 'ar',
        Lang.ckb => 'ckb,ar,en',
        Lang.en => 'en',
      };

  static Future<List<Place>> suggest(String query, {double? nearLat, double? nearLon}) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final open = await _openStreetMap(q, nearLat: nearLat, nearLon: nearLon);
    if (open.isNotEmpty) return open;
    return _mapbox(q, nearLat: nearLat, nearLon: nearLon);
  }

  static Future<List<Place>> _openStreetMap(
    String q, {
    double? nearLat,
    double? nearLon,
  }) async {
    try {
      const span = 0.35;
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '8',
        'countrycodes': 'iq',
        'addressdetails': '1',
        'accept-language': _language,
        if (nearLat != null && nearLon != null)
          'viewbox': '${nearLon - span},${nearLat + span},'
              '${nearLon + span},${nearLat - span}',
      });

      final res = await http
          .get(uri, headers: {'User-Agent': _agent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! List) return const [];

      final out = <Place>[];
      final seen = <String>{};
      for (final row in body) {
        if (row is! Map) continue;
        final lat = double.tryParse('${row['lat']}');
        final lon = double.tryParse('${row['lon']}');
        if (lat == null || lon == null) continue;

        final full = ('${row['display_name'] ?? ''}').trim();
        if (full.isEmpty) continue;
        final parts = full.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

        var name = ('${row['name'] ?? ''}').trim();
        if (name.isEmpty) name = parts.isEmpty ? full : parts.first;
        if (parts.isNotEmpty && parts.first == name) parts.removeAt(0);

        final key = '$name|${lat.toStringAsFixed(4)}|${lon.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        out.add(Place(name: name, detail: parts.take(3).join(', '), lat: lat, lon: lon));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Place>> _mapbox(String q, {double? nearLat, double? nearLon}) async {
    if (MapTiles.token.isEmpty) return const [];

    try {
      final uri = Uri.https('api.mapbox.com', '/search/geocode/v6/forward', {
        'q': q,
        'access_token': MapTiles.token,
        'country': 'iq',
        'limit': '6',
        if (nearLat != null && nearLon != null) 'proximity': '$nearLon,$nearLat',
        if (AppLocale.current.value != Lang.ckb)
          'language': AppLocale.current.value == Lang.ar ? 'ar' : 'en',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map || body['features'] is! List) return const [];

      final out = <Place>[];
      for (final f in body['features'] as List) {
        if (f is! Map) continue;
        final props = f['properties'];
        if (props is! Map) continue;

        final coords = props['coordinates'];
        final lat = coords is Map ? (coords['latitude'] as num?)?.toDouble() : null;
        final lon = coords is Map ? (coords['longitude'] as num?)?.toDouble() : null;
        if (lat == null || lon == null) continue;

        final name = ('${props['name'] ?? ''}').trim();
        if (name.isEmpty) continue;

        final full = ('${props['full_address'] ?? props['place_formatted'] ?? ''}').trim();
        final parts = full.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        if (parts.isNotEmpty && parts.first == name) parts.removeAt(0);

        out.add(Place(name: name, detail: parts.take(3).join(', '), lat: lat, lon: lon));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

class Geocode {
  Geocode._();

  static bool get available => MapTiles.token.isNotEmpty;

  static final Map<String, String?> _seen = {};

  static String _key(double lat, double lon) =>
      '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

  static Future<String?> at(double lat, double lon) async {
    if (!available) return null;
    final key = _key(lat, lon);
    if (_seen.containsKey(key)) return _seen[key];

    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/$lon,$lat.json',
        {
          'access_token': MapTiles.token,
          'types': 'address,poi,neighborhood,locality,place',
          if (AppLocale.current.value == Lang.ar) 'language': 'ar',
          if (AppLocale.current.value == Lang.en) 'language': 'en',
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;

      final text = _compose(body['features']);
      _seen[key] = text;
      return text;
    } catch (_) {
      return null;
    }
  }

  static String? _compose(Object? features) {
    if (features is! List || features.isEmpty) return null;

    final first = features.first;
    if (first is! Map) return null;

    final text = first['place_name'] ?? first['text'];
    if (text is! String || text.trim().isEmpty) return null;

    final head = text
        .split(',')
        .take(3)
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    return head.isEmpty ? null : head.join(', ');
  }

}
