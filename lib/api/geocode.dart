import 'dart:convert';

import 'package:http/http.dart' as http;

import '../i18n/strings.dart';

/// Turns a point on the map into an address a person would recognise.
///
/// The address box on "Where we live" opened empty even when the pin was
/// already sitting on the family's front door. So the one line the office reads
/// when it decides which stop a child rides from had to be typed out from
/// nothing — in a country where a written address is usually a description
/// rather than a number and a street name, and where the parent typing it is
/// often doing so one-handed.
///
/// OpenStreetMap's Nominatim: the same data behind the tiles already drawn on
/// that map, so there is no second provider, no key and no bill.
class Geocode {
  Geocode._();

  static const _host = 'nominatim.openstreetmap.org';

  /// Nominatim's terms require an application to identify itself and refuse
  /// anonymous traffic. A blocked geocoder shows up as a box that silently
  /// stays empty, so this is not decoration.
  static const _agent = 'KSP/1.0 (+https://kurdistanstudentprotection.com)';

  /// Answers already seen, so nudging the pin back and forth costs one request
  /// rather than ten. Four decimal places is about eleven metres — finer than
  /// the gap between two front doors, coarser than the jitter of a fingertip.
  static final Map<String, String?> _seen = {};

  static String _key(double lat, double lon) =>
      '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

  /// The address at a point, or null when there is nothing useful there.
  ///
  /// Never throws. An address that cannot be fetched leaves the box exactly as
  /// it was, which is what it did before any of this existed.
  static Future<String?> at(double lat, double lon) async {
    final key = _key(lat, lon);
    if (_seen.containsKey(key)) return _seen[key];

    try {
      final uri = Uri.https(_host, '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lon',
        // House and street, rather than the whole postal envelope.
        'zoom': '18',
        'addressdetails': '1',
        // Kurdish and Arabic names where OSM carries them, which in Erbil it
        // largely does — the tiles on the screen are already labelled in them.
        'accept-language': AppLocale.current.value.code,
      });

      final res = await http
          .get(uri, headers: const {'User-Agent': _agent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;

      final text = _compose(body['address'], body['display_name']);
      _seen[key] = text;
      return text;
    } catch (_) {
      // Offline, rate-limited, or a shape that has changed under us. The box
      // stays as it was and the parent types, as they had to before.
      return null;
    }
  }

  /// Keeps the near end of the address and drops the rest.
  ///
  /// display_name is the full envelope — house, road, quarter, district, city,
  /// governorate, postcode, country. A parent recognises the first few of those;
  /// the rest is noise the office has to read past to find the part that says
  /// which street the bus turns into.
  static String? _compose(Object? address, Object? fallback) {
    if (address is Map) {
      const near = [
        'house_number',
        'road',
        'neighbourhood',
        'quarter',
        'suburb',
        'city_district',
      ];
      final parts = <String>[
        for (final k in near)
          if (address[k] is String && (address[k] as String).trim().isNotEmpty)
            (address[k] as String).trim(),
      ];
      if (parts.isNotEmpty) return parts.join(', ');
    }

    if (fallback is String && fallback.trim().isNotEmpty) {
      final head = fallback.split(',').take(3).map((p) => p.trim()).where((p) => p.isNotEmpty);
      if (head.isNotEmpty) return head.join(', ');
    }
    return null;
  }
}
