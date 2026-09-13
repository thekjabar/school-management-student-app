import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../api/directions.dart';
import '../../api/offline_cache.dart';
import 'run_order.dart';

class PinnedOrder {
  const PinnedOrder({required this.order, required this.basis, required this.road});

  final List<String> order;
  final RunBasis basis;
  final bool road;

  Map<String, Object?> toJson() => {'order': order, 'basis': basis.name, 'road': road};

  static PinnedOrder? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final order = raw['order'];
    final basis = RunBasis.values.where((b) => b.name == raw['basis']).firstOrNull;
    if (order is! List || basis == null) return null;
    return PinnedOrder(order: [for (final id in order) '$id'], basis: basis, road: raw['road'] == true);
  }
}

class BusLeg {
  const BusLeg({required this.from, this.line});

  final LatLng from;

  final List<LatLng>? line;

  Map<String, Object?> toJson() => {
        'from': [from.latitude, from.longitude],
        'line': line == null ? null : Directions.encodePolyline6(line!),
      };

  static BusLeg? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final from = raw['from'];
    if (from is! List || from.length != 2 || from[0] is! num || from[1] is! num) return null;
    final line = raw['line'];
    final decoded = line is String ? Directions.decodePolyline6(line) : null;
    return BusLeg(
      from: LatLng((from[0] as num).toDouble(), (from[1] as num).toDouble()),
      line: decoded != null && decoded.length >= 2 ? decoded : null,
    );
  }
}

class RunRouteBook {
  static const _keepRoutes = 4;
  static const _keepBusLegs = 40;
  static const _keepOrders = 8;

  final Map<String, List<List<LatLng>>> routes = {};
  final Map<String, BusLeg> busLegs = {};
  final Map<String, PinnedOrder> orders = {};
  final Map<String, List<double?>> matrix = {};

  bool hasRoute(String key) => routes.containsKey(key);

  bool decidedBusLeg(String key) => busLegs.containsKey(key);

  void putRoute(String key, List<List<LatLng>> legs) {
    routes.remove(key);
    routes[key] = legs;
    _trim(routes, _keepRoutes);
  }

  void putBusLeg(String key, BusLeg leg) {
    busLegs.remove(key);
    busLegs[key] = leg;
    _trim(busLegs, _keepBusLegs);
  }

  void putOrder(String phase, PinnedOrder order) {
    orders.remove(phase);
    orders[phase] = order;
    _trim(orders, _keepOrders);
  }

  static void _trim(Map<String, Object?> map, int keep) {
    while (map.length > keep) {
      map.remove(map.keys.first);
    }
  }

  Map<String, Object?> toJson() => {
        'routes': {
          for (final e in routes.entries) e.key: [for (final leg in e.value) Directions.encodePolyline6(leg)],
        },
        'busLegs': {for (final e in busLegs.entries) e.key: e.value.toJson()},
        'orders': {for (final e in orders.entries) e.key: e.value.toJson()},
        'matrix': matrix,
      };

  static RunRouteBook fromJson(Object? raw) {
    final book = RunRouteBook();
    if (raw is! Map) return book;
    final routes = raw['routes'];
    if (routes is Map) {
      routes.forEach((key, legs) {
        if (legs is! List) return;
        final decoded = [for (final leg in legs) if (leg is String) Directions.decodePolyline6(leg)];
        if (decoded.length == legs.length && decoded.every((l) => l.length >= 2)) {
          book.routes['$key'] = decoded;
        }
      });
    }
    final busLegs = raw['busLegs'];
    if (busLegs is Map) {
      busLegs.forEach((key, value) {
        final leg = BusLeg.fromJson(value);
        if (leg != null) book.busLegs['$key'] = leg;
      });
    }
    final orders = raw['orders'];
    if (orders is Map) {
      orders.forEach((key, value) {
        final order = PinnedOrder.fromJson(value);
        if (order != null) book.orders['$key'] = order;
      });
    }
    final matrix = raw['matrix'];
    if (matrix is Map) {
      matrix.forEach((key, value) {
        if (value is! List) return;
        book.matrix['$key'] = [for (final v in value) v is num ? v.toDouble() : null];
      });
    }
    return book;
  }
}

class RunRouteCache {
  RunRouteCache._();

  static const _maxAttempts = 2;

  static final Map<String, RunRouteBook> _books = {};
  static final Map<String, Future<RunRouteBook>> _opening = {};
  static final Map<String, Future<List<List<LatLng>>?>> _routeRunning = {};
  static final Map<String, Future<BusLeg?>> _legRunning = {};
  static final Map<String, int> _attempts = {};

  static String _fileKey(String tripId) => 'driver_route.$tripId';

  static RunRouteBook? peek(String tripId) => _books[tripId];

  static Future<RunRouteBook> open(String tripId) {
    final known = _books[tripId];
    if (known != null) return Future.value(known);
    return _opening[tripId] ??= () async {
      final saved = await OfflineCache.instance.read(_fileKey(tripId));
      final book = _books[tripId] ??= RunRouteBook.fromJson(saved?.value);
      _opening.remove(tripId);
      return book;
    }();
  }

  static void _save(String tripId) {
    final book = _books[tripId];
    if (book == null) return;
    unawaited(OfflineCache.instance.write(_fileKey(tripId), book.toJson()));
  }

  static void keepOrder(String tripId, String phase, PinnedOrder order) {
    final book = _books[tripId];
    if (book == null) return;
    book.putOrder(phase, order);
    _save(tripId);
  }

  static void keepMatrix(String tripId, Map<String, List<double?>> cells) {
    final book = _books[tripId];
    if (book == null || cells.keys.every(book.matrix.containsKey)) return;
    book.matrix.addAll(cells);
    _save(tripId);
  }

  static bool _mayTry(String key) {
    final tried = _attempts[key] ?? 0;
    if (tried >= _maxAttempts) return false;
    _attempts[key] = tried + 1;
    return true;
  }

  static Future<List<List<LatLng>>?> route(
    String tripId,
    String key,
    List<LatLng> points, {
    int? schoolIndex,
  }) async {
    final book = await open(tripId);
    final ready = book.routes[key];
    if (ready != null) return ready;
    final running = _routeRunning['$tripId|$key'];
    if (running != null) return running;
    if (!_mayTry('$tripId|route|$key')) return null;
    final fetch = Directions.runLegs(points, schoolIndex: schoolIndex).then((legs) {
      _routeRunning.remove('$tripId|$key');
      if (legs != null && legs.length == points.length - 1) {
        book.putRoute(key, legs);
        _save(tripId);
      }
      return legs;
    });
    _routeRunning['$tripId|$key'] = fetch;
    return fetch;
  }

  static Future<BusLeg?> busLeg(
    String tripId,
    String key, {
    required LatLng bus,
    required LatLng target,
    required bool needed,
    required bool school,
    double? heading,
  }) async {
    final book = await open(tripId);
    final decided = book.busLegs[key];
    if (decided != null) return decided;
    final running = _legRunning['$tripId|$key'];
    if (running != null) return running;

    if (!needed) {
      final leg = BusLeg(from: bus);
      book.putBusLeg(key, leg);
      _save(tripId);
      return leg;
    }
    if (!_mayTry('$tripId|bus|$key')) return null;

    final fetch = Directions.runLegs([bus, target], startBearing: heading, schoolIndex: school ? 1 : null)
        .then((legs) {
      _legRunning.remove('$tripId|$key');
      if (legs == null || legs.isEmpty) return null;
      final leg = BusLeg(from: bus, line: legs.first);
      book.putBusLeg(key, leg);
      _save(tripId);
      return leg;
    });
    _legRunning['$tripId|$key'] = fetch;
    return fetch;
  }
}
