import 'family_payments.dart';

abstract final class EventReplyKind {
  static const yes = 'YES';
  static const no = 'NO';
  static const maybe = 'MAYBE';
}

abstract final class CanteenOrderState {
  static const placed = 'PLACED';
  static const collected = 'COLLECTED';
  static const missed = 'MISSED';
  static const cancelled = 'CANCELLED';
}

abstract final class CanteenLedgerKind {
  static const topUp = 'TOP_UP';
  static const topUpReversal = 'TOP_UP_REVERSAL';
  static const order = 'ORDER';
  static const orderRefund = 'ORDER_REFUND';
  static const adjustment = 'ADJUSTMENT';
}

String? _text(Object? raw) {
  if (raw is! String) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _int(Object? raw) => raw is num ? raw.toInt() : 0;

int? _intOrNull(Object? raw) => raw is num ? raw.toInt() : null;

bool _bool(Object? raw) => raw == true;

DateTime? _instant(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

DateTime? _dayDate(Object? raw) {
  if (raw is! String || raw.length < 10) return null;
  final parts = raw.substring(0, 10).split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String dayKeyOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

List<String> _words(Object? raw) =>
    raw is List ? [for (final v in raw) if (v is String && v.isNotEmpty) v] : const <String>[];

class EventReply {
  const EventReply({
    required this.reply,
    required this.headcount,
    required this.note,
    required this.repliedAt,
  });

  final String reply;
  final int headcount;
  final String? note;
  final DateTime? repliedAt;

  factory EventReply.fromJson(Map<String, dynamic> j) => EventReply(
        reply: (j['reply'] ?? EventReplyKind.maybe) as String,
        headcount: _int(j['headcount']),
        note: _text(j['note']),
        repliedAt: _instant(j['repliedAt']),
      );
}

class SchoolEventItem {
  const SchoolEventItem({
    required this.id,
    required this.title,
    required this.titleNames,
    required this.description,
    required this.descriptionNames,
    required this.place,
    required this.placeNames,
    required this.startsAt,
    required this.endsAt,
    required this.day,
    required this.cancelled,
    required this.replyWanted,
    required this.replyClosesAt,
    required this.replyClosed,
    required this.canReply,
    required this.headcountWanted,
    required this.headcountMax,
    required this.myReply,
  });

  final String id;
  final String title;
  final LocalText titleNames;
  final String? description;
  final LocalText descriptionNames;
  final String? place;
  final LocalText placeNames;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime day;
  final bool cancelled;
  final bool replyWanted;
  final DateTime? replyClosesAt;
  final bool replyClosed;
  final bool canReply;
  final bool headcountWanted;
  final int headcountMax;
  final EventReply? myReply;

  String get titleText => titleNames.pick(title);

  String get descriptionText => descriptionNames.pick(description);

  String get placeText => placeNames.pick(place);

  bool get awaitingReply => canReply && myReply == null;

  factory SchoolEventItem.fromJson(Map<String, dynamic> j) {
    final starts = _instant(j['startsAt']) ?? DateTime.now();
    final reply = j['myReply'];
    return SchoolEventItem(
      id: (j['id'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      titleNames: LocalText.fromJson(j['titleNames']),
      description: _text(j['description']),
      descriptionNames: LocalText.fromJson(j['descriptionNames']),
      place: _text(j['place']),
      placeNames: LocalText.fromJson(j['placeNames']),
      startsAt: starts,
      endsAt: _instant(j['endsAt']),
      day: _dayDate(j['day']) ?? DateTime(starts.year, starts.month, starts.day),
      cancelled: _bool(j['cancelled']),
      replyWanted: _bool(j['replyWanted']),
      replyClosesAt: _instant(j['replyClosesAt']),
      replyClosed: _bool(j['replyClosed']),
      canReply: _bool(j['canReply']),
      headcountWanted: _bool(j['headcountWanted']),
      headcountMax: _intOrNull(j['headcountMax']) ?? 1,
      myReply: reply is Map<String, dynamic> ? EventReply.fromJson(reply) : null,
    );
  }
}

class CanteenBalance {
  const CanteenBalance({
    required this.balanceIqd,
    required this.dailyLimitIqd,
    required this.dailyLimitIsMine,
    required this.low,
    required this.lowBalanceIqd,
    required this.updatedAt,
    required this.today,
    required this.lastDayYouCanOrder,
    required this.cutoffHour,
    required this.cutoffMinute,
  });

  final int balanceIqd;
  final int? dailyLimitIqd;
  final bool dailyLimitIsMine;
  final bool low;
  final int lowBalanceIqd;
  final DateTime? updatedAt;
  final String today;
  final String lastDayYouCanOrder;
  final int cutoffHour;
  final int cutoffMinute;

  int get cutoffMinuteOfDay => cutoffHour * 60 + cutoffMinute;

  DateTime get firstDay => _dayDate(today) ?? DateTime.now();

  DateTime get lastDay => _dayDate(lastDayYouCanOrder) ?? firstDay;

  factory CanteenBalance.fromJson(Map<String, dynamic> j) => CanteenBalance(
        balanceIqd: _int(j['balanceIqd']),
        dailyLimitIqd: _intOrNull(j['dailyLimitIqd']),
        dailyLimitIsMine: _bool(j['dailyLimitIsMine']),
        low: _bool(j['low']),
        lowBalanceIqd: _int(j['lowBalanceIqd']),
        updatedAt: _instant(j['updatedAt']),
        today: (j['today'] ?? '') as String,
        lastDayYouCanOrder: (j['lastDayYouCanOrder'] ?? '') as String,
        cutoffHour: _int(j['cutoffHour']),
        cutoffMinute: _int(j['cutoffMinute']),
      );
}

class CanteenMenuItem {
  const CanteenMenuItem({
    required this.id,
    required this.name,
    required this.names,
    required this.description,
    required this.descriptionNames,
    required this.priceIqd,
    required this.allergens,
    required this.allergyWarnings,
  });

  final String id;
  final String name;
  final LocalText names;
  final String? description;
  final LocalText descriptionNames;
  final int priceIqd;
  final List<String> allergens;
  final List<String> allergyWarnings;

  String get nameText => names.pick(name);

  String get descriptionText => descriptionNames.pick(description);

  bool get clashesWithAllergy => allergyWarnings.isNotEmpty;

  factory CanteenMenuItem.fromJson(Map<String, dynamic> j) => CanteenMenuItem(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        names: LocalText.fromJson(j['names']),
        description: _text(j['description']),
        descriptionNames: LocalText.fromJson(j['descriptionNames']),
        priceIqd: _int(j['priceIqd']),
        allergens: _words(j['allergens']),
        allergyWarnings: _words(j['allergyWarnings']),
      );
}

class CanteenOrderLine {
  const CanteenOrderLine({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unitPriceIqd,
    required this.lineTotalIqd,
  });

  final String itemId;
  final String name;
  final int quantity;
  final int unitPriceIqd;
  final int lineTotalIqd;

  factory CanteenOrderLine.fromJson(Map<String, dynamic> j) => CanteenOrderLine(
        itemId: (j['itemId'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        quantity: _int(j['quantity']),
        unitPriceIqd: _int(j['unitPriceIqd']),
        lineTotalIqd: _int(j['lineTotalIqd']),
      );
}

class CanteenOrder {
  const CanteenOrder({
    required this.id,
    required this.day,
    required this.status,
    required this.totalIqd,
    required this.cutoffAt,
    required this.allergyWarned,
    required this.collectedAt,
    required this.placedAt,
    required this.lines,
    required this.balanceIqd,
  });

  final String id;
  final String day;
  final String status;
  final int totalIqd;
  final DateTime? cutoffAt;
  final bool allergyWarned;
  final DateTime? collectedAt;
  final DateTime? placedAt;
  final List<CanteenOrderLine> lines;
  final int? balanceIqd;

  DateTime get date => _dayDate(day) ?? DateTime.now();

  bool get live => status == CanteenOrderState.placed;

  bool get changeable =>
      live && cutoffAt != null && cutoffAt!.isAfter(DateTime.now());

  factory CanteenOrder.fromJson(Map<String, dynamic> j) => CanteenOrder(
        id: (j['id'] ?? '') as String,
        day: (j['day'] ?? '') as String,
        status: (j['status'] ?? CanteenOrderState.placed) as String,
        totalIqd: _int(j['totalIqd']),
        cutoffAt: _instant(j['cutoffAt']),
        allergyWarned: _bool(j['allergyWarned']),
        collectedAt: _instant(j['collectedAt']),
        placedAt: _instant(j['placedAt']),
        lines: ((j['lines'] as List?) ?? const [])
            .map((e) => CanteenOrderLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        balanceIqd: _intOrNull(j['balanceIqd']),
      );
}

class CanteenDayMenu {
  const CanteenDayMenu({
    required this.day,
    required this.weekday,
    required this.cutoffAt,
    required this.ordersClosed,
    required this.items,
    required this.order,
  });

  final String day;
  final String weekday;
  final DateTime? cutoffAt;
  final bool ordersClosed;
  final List<CanteenMenuItem> items;
  final CanteenOrder? order;

  DateTime get date => _dayDate(day) ?? DateTime.now();

  factory CanteenDayMenu.fromJson(Map<String, dynamic> j) {
    final order = j['order'];
    return CanteenDayMenu(
      day: (j['day'] ?? '') as String,
      weekday: (j['weekday'] ?? '') as String,
      cutoffAt: _instant(j['cutoffAt']),
      ordersClosed: _bool(j['ordersClosed']),
      items: ((j['items'] as List?) ?? const [])
          .map((e) => CanteenMenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      order: order is Map<String, dynamic> ? CanteenOrder.fromJson(order) : null,
    );
  }
}

class CanteenLedgerRow {
  const CanteenLedgerRow({
    required this.id,
    required this.kind,
    required this.amountIqd,
    required this.balanceAfterIqd,
    required this.reason,
    required this.day,
    required this.at,
  });

  final String id;
  final String kind;
  final int amountIqd;
  final int balanceAfterIqd;
  final String? reason;
  final String? day;
  final DateTime? at;

  bool get addsMoney => amountIqd >= 0;

  factory CanteenLedgerRow.fromJson(Map<String, dynamic> j) => CanteenLedgerRow(
        id: (j['id'] ?? '') as String,
        kind: (j['kind'] ?? CanteenLedgerKind.adjustment) as String,
        amountIqd: _int(j['amountIqd']),
        balanceAfterIqd: _int(j['balanceAfterIqd']),
        reason: _text(j['reason']),
        day: _text(j['day']),
        at: _instant(j['at']),
      );
}

class CanteenLimit {
  const CanteenLimit({
    required this.balanceIqd,
    required this.dailyLimitIqd,
    required this.dailyLimitIsMine,
  });

  final int balanceIqd;
  final int? dailyLimitIqd;
  final bool dailyLimitIsMine;

  factory CanteenLimit.fromJson(Map<String, dynamic> j) => CanteenLimit(
        balanceIqd: _int(j['balanceIqd']),
        dailyLimitIqd: _intOrNull(j['dailyLimitIqd']),
        dailyLimitIsMine: _bool(j['dailyLimitIsMine']),
      );
}
