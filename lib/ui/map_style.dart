/// The Google map, repainted in the app's own palette.
///
/// Google's default basemap is somebody else's product: saturated motorways, a
/// hundred restaurant pins, a blue that belongs to no other screen here. Drop
/// it whole into the tracking screen and the one page a parent opens when they
/// are worried looks pasted in from another application.
///
/// So the map is styled, and styled from the SAME TOKENS as everything else:
/// not one hex value is typed out below. Every colour is [AppTheme]'s, or a
/// blend of two of AppTheme's, which means the dark variant is not a second
/// palette somebody has to keep in step by hand — it is this same code reading
/// these same getters after [AppTheme.dark] has flipped.
///
/// What it says, in short: soft neutral ground, roads a shade above it rather
/// than a colour of their own, water and parks tinted out of the app's own blue
/// and green, almost no points of interest, and labels in the app's muted text
/// colour over a halo of the ground behind them.
///
/// Styling is a client-side operation on the native SDK. It costs nothing and
/// it asks no Google service for anything.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The style, as the JSON string `GoogleMap.style` takes.
///
/// Call it inside `build`, not once at startup: every colour it names is a
/// getter that answers differently depending on [AppTheme.dark], so a style
/// built at launch would keep the map light after the rest of the app had gone
/// dark.
String mapStyleJson() => jsonEncode(_rules());

/// `#rrggbb`, the only form the styler accepts. Alpha is dropped — the map has
/// nothing behind it to blend against.
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// [a] with [t] of [b] mixed into it — how every tinted surface below is
/// arrived at, so that a park is the app's green *seen through* the app's
/// ground rather than a green somebody picked to sit beside it.
Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Later rules win, so the order here is load-bearing: the sweeping ones first,
/// then the exceptions carved back out of them.
List<Map<String, Object>> _rules() {
  // AppTheme.canvas — the page every card in the app floats on. The map is a
  // surface of the same family, so the ground under it is literally that.
  final ground = AppTheme.canvas;
  // AppTheme.surface — the card colour. Roads then read as the thing lifted off
  // the ground, which is the relationship a card already has to the page, and
  // it holds in both themes: white on near-white in the light, a shade above
  // navy in the dark.
  final road = AppTheme.surface;
  // AppTheme.border — the app's hairline, doing here exactly the job it does
  // everywhere else: road casings and boundaries.
  final line = AppTheme.border;
  // AppTheme.textMuted and AppTheme.textFaint — the two label weights, taken
  // straight across.
  final label = AppTheme.textMuted;
  final labelFaint = AppTheme.textFaint;

  return [
    // ---- The ground --------------------------------------------------------
    // AppTheme.canvas.
    {
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(ground)},
      ],
    },

    // ---- Type --------------------------------------------------------------
    // AppTheme.textMuted over a halo of AppTheme.canvas: the pairing the app
    // uses for a caption on a page, so a street name reads at arm's length
    // without becoming the loudest thing on the map.
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
    // Google's own pictograms, off everywhere. They are the single largest
    // source of clutter on the default map, and not one of them is about this
    // child, this bus or this stop.
    {
      'elementType': 'labels.icon',
      'stylers': [
        {'visibility': 'off'},
      ],
    },

    // ---- Boundaries --------------------------------------------------------
    // AppTheme.border.
    {
      'featureType': 'administrative',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(line)},
      ],
    },
    // Plot outlines: a grey mesh over every residential block, and nothing a
    // parent is looking for.
    {
      'featureType': 'administrative.land_parcel',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
    // AppTheme.textFaint — a quarter's name is orientation, not information.
    {
      'featureType': 'administrative.neighborhood',
      'elementType': 'labels.text.fill',
      'stylers': [
        {'color': _hex(labelFaint)},
      ],
    },

    // ---- Land --------------------------------------------------------------
    // AppTheme.canvas carrying rather over half of AppTheme.border: buildings a
    // shade off the ground, enough to give a street its shape and no more.
    {
      'featureType': 'landscape.man_made',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(_mix(ground, line, 0.55))},
      ],
    },
    // AppTheme.canvas with a tenth of AppTheme.green.
    {
      'featureType': 'landscape.natural',
      'elementType': 'geometry',
      'stylers': [
        {'color': _hex(_mix(ground, AppTheme.green, 0.10))},
      ],
    },

    // ---- Points of interest ------------------------------------------------
    // Off, wholesale — then two exceptions put back, because both are things a
    // parent genuinely navigates by while working out where a bus has got to.
    {
      'featureType': 'poi',
      'stylers': [
        {'visibility': 'off'},
      ],
    },
    // Parks: AppTheme.canvas with a fifth of AppTheme.green, named in
    // AppTheme.textMuted pulled a third of the way towards the same green.
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
    // Schools stay named. The app cannot draw the school as a pin of its own —
    // nothing the platform sends carries its coordinates — and Google already
    // knows where the schools are, so this is the one place the basemap says
    // something the payload cannot.
    //
    // AppTheme.canvas with a tenth of Role.parent.tint, labelled in
    // AppTheme.textMuted.
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

    // ---- Roads -------------------------------------------------------------
    // AppTheme.surface, cased in AppTheme.border, named in AppTheme.textFaint.
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
    // The through-roads, firmer by degrees rather than by hue: AppTheme.surface
    // carrying a seventh, then a quarter, of AppTheme.textFaint. Colour in this
    // app means something — good, late, happening now — and a motorway is none
    // of those, so it gets weight instead.
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
    // The route shields: big, coloured, and about a road number nobody reading
    // this screen has asked for.
    {
      'featureType': 'road.highway',
      'elementType': 'labels.icon',
      'stylers': [
        {'visibility': 'off'},
      ],
    },

    // ---- Transit -----------------------------------------------------------
    // Off. The one vehicle this screen is about is drawn by us.
    {
      'featureType': 'transit',
      'stylers': [
        {'visibility': 'off'},
      ],
    },

    // ---- Water -------------------------------------------------------------
    // AppTheme.canvas with just under a third of AppTheme.blue — the app's own
    // blue seen through its own ground, instead of the basemap's postcard cyan.
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
