import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:url_launcher/url_launcher.dart';

import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'sheets.dart';

class MapTiles {
  MapTiles._();

  static const _fallbackStyle = 'mapbox/light-v11';

  static const _styleOverride = String.fromEnvironment('MAPBOX_STYLE');

  static String get _style =>
      _styleOverride.isEmpty ? _fallbackStyle : _styleOverride;

  static String get styleUri => 'mapbox://styles/$_style';

  static const token = String.fromEnvironment('MAPBOX_TOKEN');

  static bool get configured => token.isNotEmpty;

  static final trouble = ValueNotifier<bool>(false);

  static TileLayer layer() => TileLayer(
        urlTemplate:
            'https://api.mapbox.com/styles/v1/$_style/tiles/512/{z}/{x}/{y}@2x'
            '?access_token=$token',
        errorTileCallback: (_, _, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) => trouble.value = true);
        },
        tileBuilder: (context, tileWidget, tile) {
          if (tile.loadError == false && trouble.value) {
            WidgetsBinding.instance.addPostFrameCallback((_) => trouble.value = false);
          }
          return tileWidget;
        },
        tileDimension: 512,
        zoomOffset: -1,
        userAgentPackageName: 'com.kurdistanstudentprotection.ksp',
        maxNativeZoom: 20,
      );

  static const credit = '© Mapbox © OpenStreetMap';
  static const improve = 'Improve this map';

  static const mapboxUrl = 'https://www.mapbox.com/about/maps/';
  static const osmUrl = 'https://www.openstreetmap.org/copyright/';
  static const improveUrl = 'https://www.mapbox.com/contribute/';
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, this.small = false});

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
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
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
