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

  static bool get available => MapTiles.token.isNotEmpty;

  static Future<List<Place>> suggest(String query, {double? nearLat, double? nearLon}) async {
    final q = query.trim();
    if (q.length < 2 || !available) return const [];

    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json',
        {
          'access_token': MapTiles.token,
          'country': 'iq',
          'limit': '6',
          'types': 'address,poi,neighborhood,locality,place,district',
          if (nearLat != null && nearLon != null)
            'proximity': '$nearLon,$nearLat',
          if (AppLocale.current.value == Lang.ar) 'language': 'ar',
          if (AppLocale.current.value == Lang.en) 'language': 'en',
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map || body['features'] is! List) return const [];

      final out = <Place>[];
      for (final f in body['features'] as List) {
        if (f is! Map) continue;
        final centre = f['center'];
        if (centre is! List || centre.length < 2) continue;
        final lon = (centre[0] as num?)?.toDouble();
        final lat = (centre[1] as num?)?.toDouble();
        if (lat == null || lon == null) continue;

        final name = (f['text'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;

        final full = (f['place_name'] as String?)?.trim() ?? '';
        final rest = full.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        if (rest.isNotEmpty && rest.first == name) rest.removeAt(0);

        out.add(Place(name: name, detail: rest.take(2).join(', '), lat: lat, lon: lon));
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
