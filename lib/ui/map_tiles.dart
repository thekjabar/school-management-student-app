import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../i18n/strings.dart';
import '../theme/app_theme.dart';

/// The one place in this app that knows where map tiles come from.
///
/// Three screens draw a map — the parent's bus tracking, the parent's home
/// address, and the driver's route — and each used to carry its own copy of a
/// tile URL. Three copies is three places to forget on the day a token is
/// rotated, and the one that gets forgotten is the one a driver is holding at
/// half past six in the morning.
class MapTiles {
  MapTiles._();

  /// The Mapbox style these tiles are rendered from.
  ///
  /// Raster rather than the native Mapbox SDK deliberately: that SDK downloads
  /// itself from Mapbox's Maven repository and needs a SECRET token to do it
  /// (sk., scope DOWNLOADS:READ), which is a different credential from the
  /// public one an app ships with. Until that exists this cannot build at all,
  /// while flutter_map — already here, already drawing every one of these
  /// screens — takes the same style as a tile URL and keeps every marker and
  /// polyline already written against it.
  ///
  /// THE STYLE MUST BE A CLASSIC ONE. It cannot be a Mapbox Standard style.
  ///
  /// This is not a preference, it is what the endpoint will draw. A Standard
  /// style (anything Studio creates from the default template today) carries no
  /// layers of its own — it is one line, `imports: mapbox://styles/mapbox/
  /// standard`, resolved at draw time by the GL SDKs. The Raster Tiles API does
  /// not resolve imports: it renders the style's own layers, finds none, and
  /// answers 200 with a 235-byte transparent PNG. Every tile. Every zoom.
  ///
  /// So it fails as a working map that happens to be empty, not as an error —
  /// nothing logs, nothing retries, no status code is out of place, and the
  /// screen shows the grey behind the tiles with the markers and the credit
  /// drawn neatly on top. `mapbox/standard` asked for by name at least answers
  /// 400; a style that merely imports it does not.
  ///
  /// A classic style — Streets, Light, Outdoors, or one built on those in
  /// Studio — has real layers and renders. To check any candidate before
  /// shipping it, fetch one tile over a city and look at the SIZE, never the
  /// status: a drawn tile is tens to hundreds of kilobytes.
  ///
  /// Overridable so that swapping in the school's own classic style, once one
  /// exists, is a build flag rather than a code change:
  ///
  ///   flutter build apk --dart-define=MAPBOX_STYLE=owner/styleid
  ///
  /// Worth knowing when the bill arrives: raster tiles are charged per TILE,
  /// where the native SDK is charged per map LOAD. A parent panning around a
  /// tracking screen pulls a good many tiles.
  /// Light: near-white land, pale water, muted roads, no POI clutter — the
  /// closest classic stand-in for the school's Standard style, whose config is
  /// all pale (land hsl(228,45%,98%), water hsl(209,100%,93%), roads white, POI
  /// labels off) and which cannot be drawn through this endpoint at all.
  static const _fallbackStyle = 'mapbox/light-v11';

  static const _styleOverride = String.fromEnvironment('MAPBOX_STYLE');

  /// Checked for EMPTY, not just for absence.
  ///
  /// `String.fromEnvironment` treats a define that was passed as blank —
  /// `--dart-define=MAPBOX_STYLE=`, which is exactly what the build script
  /// produces when the school has not supplied a style file — as a value, and
  /// hands back the empty string rather than the default. The URL would then
  /// read `/styles/v1//tiles/...` and every tile would 404, on a build whose
  /// output looks completely normal.
  static String get _style =>
      _styleOverride.isEmpty ? _fallbackStyle : _styleOverride;

  /// Supplied at build time, never committed.
  ///
  /// A Mapbox public token is designed to ship inside a client and can be read
  /// out of any APK, so this is not secrecy — it is about keeping it out of a
  /// PUBLIC repository, where anyone who clones the code can spend the school's
  /// quota without ever touching the app.
  ///
  ///   flutter build apk --dart-define=MAPBOX_TOKEN=pk...
  ///
  /// tool/build_apks.sh passes it from tool/mapbox.token, which is gitignored.
  static const token = String.fromEnvironment('MAPBOX_TOKEN');

  static bool get configured => token.isNotEmpty;

  /// The tile layer every map uses.
  ///
  /// 512px tiles at @2x: fewer requests than 256px for the same ground, and
  /// crisp on the phones these are actually read on.
  static TileLayer layer() => TileLayer(
        urlTemplate:
            'https://api.mapbox.com/styles/v1/$_style/tiles/512/{z}/{x}/{y}@2x'
            '?access_token=$token',
        // The style is served at 512, so a tile covers one zoom level more
        // than the default. Without this every label renders half-size.
        tileDimension: 512,
        zoomOffset: -1,
        userAgentPackageName: 'com.kurdistanstudentprotection.ksp',
        maxNativeZoom: 20,
      );

  /// The credit line, which is not optional.
  ///
  /// Mapbox's terms require both their name and OpenStreetMap's on the map:
  /// Mapbox draws these tiles, and it draws them from OpenStreetMap's data.
  ///
  /// It reads as one string rather than a widget because each screen has a
  /// different free corner and already styles its own. What must not vary is
  /// the text — three screens spent a day claiming to be a map they were not.
  static const credit = '© Mapbox © OpenStreetMap';
}

/// Drawn in place of a map when no token was built in.
///
/// A map with no token renders as a grey rectangle with no explanation, which
/// looks exactly like a map that is still loading, or a bus that has not
/// started, or a broken connection. Saying which it is costs one widget.
class MapNotConfigured extends StatelessWidget {
  const MapNotConfigured({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.neutralSoft,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 30, color: AppTheme.textFaint),
              const SizedBox(height: 10),
              Text(
                t('map.noToken'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
