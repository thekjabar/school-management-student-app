import 'dart:convert';

import 'package:http/http.dart' as http;

import '../i18n/strings.dart';
import '../ui/map_tiles.dart';

/// A place the search offered, and where it is.
class Place {
  const Place({required this.name, required this.detail, required this.lat, required this.lon});

  /// The bit worth reading first — a quarter, a mosque, a street.
  final String name;

  /// Where that is, for telling two places of the same name apart. Empty when
  /// the name is already unambiguous.
  final String detail;

  final double lat;
  final double lon;
}

/// Searching for a place by name, rather than dragging the map to find it.
///
/// Dragging works when you already know where you are on a map. It is a poor
/// way to find Bakhtiyari from a standing start, and worse one-handed, which is
/// how a parent fills this in. Typing the name and being taken there is the
/// short way.
///
/// Mapbox rather than Nominatim for this one: the tiles under the pin are
/// already Mapbox, so a search that agrees with what is drawn beats a second
/// provider's idea of where a quarter begins. Reverse geocoding stays on
/// Nominatim — it is doing a different job and it is free.
class PlaceSearch {
  PlaceSearch._();

  static bool get available => MapTiles.token.isNotEmpty;

  /// Places matching what has been typed, nearest to [near] first.
  ///
  /// Never throws. A search that cannot run returns nothing, which the field
  /// renders as "no results" — the map is still there to drag.
  static Future<List<Place>> suggest(String query, {double? nearLat, double? nearLon}) async {
    final q = query.trim();
    if (q.length < 2 || !available) return const [];

    try {
      final uri = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json',
        {
          'access_token': MapTiles.token,
          // Iraq only. A family setting the stop their child rides from is not
          // looking for a Bakhtiyari in another country, and every result that
          // is one is a result they have to read past.
          'country': 'iq',
          'limit': '6',
          'types': 'address,poi,neighborhood,locality,place,district',
          if (nearLat != null && nearLon != null)
            // Bias to the map they are looking at, so the nearest Runaki comes
            // first rather than the one in another governorate.
            'proximity': '$nearLon,$nearLat',
          // Only the two Mapbox actually carries. Sorani is not one of them, and
          // asking for it returns an error rather than falling back — so for a
          // Sorani reader the parameter is left off and Mapbox answers with the
          // local name, which in Erbil is usually the one on the street sign.
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

        // place_name repeats the name and then says where it is. Keeping only
        // the rest gives a second line that adds something.
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
      // House and street first, then the quarter, then the town. Nominatim's
      // own display_name runs on through governorate, postcode and country,
      // which a parent standing in the building does not need and the office
      // has to read past — but cutting at the district lost the town, and a
      // street name alone is not an address. Amenity leads because in Erbil a
      // place is very often named before it is numbered.
      const near = [
        'amenity',
        'house_number',
        'road',
        'neighbourhood',
        'quarter',
        'suburb',
        'city_district',
        'city',
        'town',
        'village',
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
