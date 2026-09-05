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
/// Mapbox, so a search agrees with the tiles drawn under the pin rather than
/// offering a second provider's idea of where a quarter begins.
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
/// Mapbox, like every other map call in this app.
///
/// This was the one exception: OpenStreetMap's Nominatim, chosen because it is
/// the same data under the tiles and costs nothing. It is a free community
/// service with published rate limits, no delivery guarantee and terms that
/// refuse anonymous traffic — fine for a hobby, wrong for the line an office
/// reads when it decides which stop a child rides from. One vendor now, one
/// contract, one place to ask why an answer was poor.
class Geocode {
  Geocode._();

  /// Reverse geocoding needs the same token the tiles do, so a build with no
  /// token has no geocoder either — and says so by leaving the box alone
  /// rather than by failing.
  static bool get available => MapTiles.token.isNotEmpty;

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
    if (!available) return null;
    final key = _key(lat, lon);
    if (_seen.containsKey(key)) return _seen[key];

    try {
      // Longitude first. Mapbox orders coordinates lon,lat throughout its API,
      // which is the opposite of how everyone says them aloud and the easiest
      // mistake to make here — reversed, an Erbil pin lands in Somalia and the
      // box fills with a confident wrong answer rather than staying empty.
      final uri = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/$lon,$lat.json',
        {
          'access_token': MapTiles.token,
          // Nearest first: the door, then the street, then the quarter. Asking
          // for the whole list and picking is what lets a pin on a house come
          // back as a house rather than as the district it sits in.
          'types': 'address,poi,neighborhood,locality,place',
          // No limit: with more than one type asked for, Mapbox refuses any
          // limit but the default of one, and returns an error rather than the
          // nearest match. The default is the nearest match, which is what we
          // want anyway.
          //
          // Language only where Mapbox has one. Sorani is not among them and
          // asking for it errors instead of falling back, so a Sorani reader
          // gets the local name — which in Erbil is usually what is on the
          // street sign. Same rule as the search above.
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
      // Offline, or a shape that has changed under us. The box stays as it was
      // and the parent types, as they had to before.
      return null;
    }
  }

  /// Keeps the near end of the address and drops the rest.
  ///
  /// display_name is the full envelope — house, road, quarter, district, city,
  /// governorate, postcode, country. A parent recognises the first few of those;
  /// the rest is noise the office has to read past to find the part that says
  /// which street the bus turns into.
  static String? _compose(Object? features) {
    if (features is! List || features.isEmpty) return null;

    // Mapbox returns the matches nearest-first, each with a place_name that
    // runs all the way out to the country. The near end is what a parent
    // recognises and what the office needs; the rest is what they have to read
    // past to find the street the bus turns into.
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
