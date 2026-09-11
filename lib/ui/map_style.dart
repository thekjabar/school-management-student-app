library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

String mapStyleJson() => jsonEncode(_rules());

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

List<Map<String, Object>> _rules() {
  final ground = AppTheme.canvas;
  final road = AppTheme.surface;
  final line = AppTheme.border;
  final label = AppTheme.textMuted;
  final labelFaint = AppTheme.textFaint;

  return [
    {
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(ground)},
      ],
    },

    {
      'elementType': 'labels.text.fill',
      'stylers': [
        {'color': _hex(label)},
      ],
    },
    {
      'elementType': 'labels.text.stroke',
      'stylers': [
        {'color': _hex(ground)},
      ],
    },
    {
      'elementType': 'labels.icon',
      'stylers': [
        {'visibility': 'off'},
      ],
    },

    {
      'featureType': 'administrative',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(line)},
      ],
    },
    {
      'featureType': 'administrative.land_parcel',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
    {
      'featureType': 'administrative.neighborhood',
      'elementType': 'labels.text.fill',
      'stylers': [
        {'color': _hex(labelFaint)},
      ],
    },

    {
      'featureType': 'landscape.man_made',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(_mix(ground, line, 0.55))},
      ],
    },
    {
      'featureType': 'landscape.natural',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(_mix(ground, AppTheme.green, 0.10))},
      ],
    },

    {
      'featureType': 'poi',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
    {
      'featureType': 'poi.park',
      'elementType': 'geometry',
      'stylers': [
        {'visibility': 'on'},
        {'color': _hex(_mix(ground, AppTheme.green, 0.20))},
      ],
    },
    {
      'featureType': 'poi.park',
      'elementType': 'labels.text.fill',
      'stylers': [
        {'visibility': 'on'},
        {'color': _hex(_mix(label, AppTheme.green, 0.35))},
      ],
    },
    {
      'featureType': 'poi.school',
      'elementType': 'geometry',
      'stylers': [
        {'visibility': 'on'},
        {'color': _hex(_mix(ground, Role.parent.tint, 0.10))},
      ],
    },
    {
      'featureType': 'poi.school',
      'elementType': 'labels.text.fill',
      'stylers': [
        {'visibility': 'on'},
        {'color': _hex(label)},
      ],
    },

    {
      'featureType': 'road',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(road)},
      ],
    },
    {
      'featureType': 'road',
      'elementType': 'geometry.stroke',
      'stylers': [
        {'color': _hex(line)},
      ],
    },
    {
      'featureType': 'road',
      'elementType': 'labels.text.fill',
      'stylers': [
        {'color': _hex(labelFaint)},
      ],
    },
    {
      'featureType': 'road.arterial',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(_mix(road, labelFaint, 0.14))},
      ],
    },
    {
      'featureType': 'road.highway',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(_mix(road, labelFaint, 0.26))},
      ],
    },
    {
      'featureType': 'road.highway',
      'elementType': 'geometry.stroke',
      'stylers': [
        {'color': _hex(_mix(line, labelFaint, 0.35))},
      ],
    },
    {
      'featureType': 'road.highway',
      'elementType': 'labels.icon',
      'stylers': [
        {'visibility': 'off'},
      ],
    },

    {
      'featureType': 'transit',
      'stylers': [
        {'visibility': 'off'},
      ],
    },

    {
      'featureType': 'water',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(_mix(ground, AppTheme.blue, 0.30))},
      ],
    },
    {
      'featureType': 'water',
      'elementType': 'labels.text.fill',
      'stylers': [
        {'color': _hex(_mix(label, AppTheme.blue, 0.40))},
      ],
    },
  ];
}
