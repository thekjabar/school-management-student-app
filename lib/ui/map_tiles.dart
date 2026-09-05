import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'sheets.dart';

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

  /// The style as the native SDK wants it named.
  ///
  /// The raster endpoint takes `owner/styleid` in a URL path; the GL engine
  /// takes the same pair as a `mapbox://styles/` URI and resolves the style's
  /// imports itself. That difference is the whole reason the engine changed —
  /// a Standard style is nothing but an import, so the raster renderer drew
  /// blank tiles from it and this one draws the map the school designed.
  static String get styleUri => 'mapbox://styles/$_style';

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
  /// True while tiles are failing to arrive.
  ///
  /// A tile that does not download leaves the map a plain grey rectangle —
  /// which is exactly what a map with no token looks like, and what a map that
  /// is still loading looks like, and what a bus that has not started looks
  /// like. MapNotConfigured was written for one of those. This is the other:
  /// the phone is on a bad connection, or Mapbox is unreachable, and the parent
  /// deserves to be told that rather than left staring at grey.
  ///
  /// Global rather than per-screen because it describes the network, not the
  /// screen, and every map in the app is drawn from the same host.
  static final trouble = ValueNotifier<bool>(false);

  static TileLayer layer() => TileLayer(
        urlTemplate:
            'https://api.mapbox.com/styles/v1/$_style/tiles/512/{z}/{x}/{y}@2x'
            '?access_token=$token',
        errorTileCallback: (_, _, _) {
          // Set after the frame: this fires during the tile's own build, and
          // notifying a listener mid-build is what makes Flutter throw.
          WidgetsBinding.instance.addPostFrameCallback((_) => trouble.value = true);
        },
        tileBuilder: (context, tileWidget, tile) {
          // One tile arriving is proof the connection came back.
          if (tile.loadError == false && trouble.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) => trouble.value = false);
          }
          return tileWidget;
        },
        // The style is served at 512, so a tile covers one zoom level more
        // than the default. Without this every label renders half-size.
        tileDimension: 512,
        zoomOffset: -1,
        userAgentPackageName: 'com.kurdistanstudentprotection.ksp',
        maxNativeZoom: 20,
      );

  /// The credit line, which is not optional, and what it is owed to.
  ///
  /// Asked of Mapbox rather than assumed: the style light-v11 draws from the
  /// source mapbox.mapbox-streets-v8, and that source's own metadata declares
  ///
  ///     © Mapbox © OpenStreetMap Improve this map
  ///
  /// OpenStreetMap is in there because the streets ARE OpenStreetMap's. Mapbox
  /// is paid for rendering, hosting and delivery, not for the data underneath,
  /// and OSM's licence — ODbL — makes the credit travel with the data wherever
  /// it goes. Mapbox cannot waive it on OSM's behalf, so they pass it on.
  ///
  /// It used to sit on the map as a pill reading '© Mapbox © OpenStreetMap',
  /// which was both intrusive and INCOMPLETE — the third element was missing.
  /// It now lives behind the ⓘ, which Mapbox permits for a mobile app where
  /// space is tight so long as it stays reachable. Off the map, and complete.
  static const credit = '© Mapbox © OpenStreetMap';
  static const improve = 'Improve this map';

  static const mapboxUrl = 'https://www.mapbox.com/about/maps/';
  static const osmUrl = 'https://www.openstreetmap.org/copyright/';
  static const improveUrl = 'https://www.mapbox.com/contribute/';
}

/// The ⓘ in the corner of every map, and the credit behind it.
///
/// A button rather than a line of text because the licence asks for the credit
/// to be present and reachable, not for it to be painted across the picture.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, this.small = false});

  /// Smaller still, for the map card on a home screen.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final side = small ? 20.0 : 24.0;
    return Semantics(
      button: true,
      label: t('map.credits'),
      child: GestureDetector(
        onTap: () => showAppSheet<void>(context, builder: (_) => const _CreditSheet()),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.86),
            shape: BoxShape.circle,
            boxShadow: AppTheme.dark
                ? null
                : const [BoxShadow(color: Color(0x14101828), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Icon(
            Icons.info_outline_rounded,
            size: small ? 12 : 14,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CreditSheet extends StatelessWidget {
  const _CreditSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            t('map.credits'),
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.text),
          ),
          const SizedBox(height: 4),
          Text(
            t('map.creditsBody'),
            style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          const _CreditLink(label: '© Mapbox', url: MapTiles.mapboxUrl),
          const _CreditLink(label: '© OpenStreetMap', url: MapTiles.osmUrl),
          _CreditLink(label: t('map.improve'), url: MapTiles.improveUrl),
        ],
      ),
    );
  }
}

class _CreditLink extends StatelessWidget {
  const _CreditLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        // A credit that cannot be opened is still a credit; a crash is not.
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          // No browser on the handset. Nothing useful to say, and nothing broken.
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.text),
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 15, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Says so when the tiles will not come.
///
/// Stacked over the map rather than replacing it: the markers, the route and
/// the stop names are all still worth reading with no tiles behind them, and
/// throwing the whole map away because the background is missing would take
/// more from the reader than it gives.
class MapOffline extends StatelessWidget {
  const MapOffline({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MapTiles.trouble,
      builder: (context, bad, _) {
        if (!bad) return const SizedBox.shrink();
        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppTheme.dark
                    ? null
                    : const [BoxShadow(color: Color(0x14101828), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    t('map.offline'),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
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
