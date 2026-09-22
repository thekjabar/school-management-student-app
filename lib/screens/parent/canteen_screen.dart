import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import '../../ui/sheets.dart';

String allergenWord(String key) => tOr('allergen.$key', humanise(key));

String ledgerWord(String kind) => switch (kind) {
      CanteenLedgerKind.topUp => t('canteen.moneyAdded'),
      CanteenLedgerKind.topUpReversal => t('canteen.moneyTakenBack'),
      CanteenLedgerKind.order => t('canteen.foodOrdered'),
      CanteenLedgerKind.orderRefund => t('canteen.moneyReturned'),
      _ => t('canteen.corrected'),
    };

String orderStateWord(String status) => switch (status) {
      CanteenOrderState.collected => t('canteen.collected'),
      CanteenOrderState.missed => t('canteen.notCollected'),
      CanteenOrderState.cancelled => t('canteen.orderCancelled'),
      _ => t('canteen.ordered'),
    };

Color orderStateTint(String status) => switch (status) {
      CanteenOrderState.collected => AppTheme.green,
      CanteenOrderState.missed => AppTheme.amber,
      CanteenOrderState.cancelled => AppTheme.textMuted,
      _ => AppTheme.blue,
    };

class CanteenScreen extends StatefulWidget {
  const CanteenScreen({super.key, required this.child});

  final Child child;

  @override
  State<CanteenScreen> createState() => _CanteenScreenState();
}

class _CanteenScreenState extends State<CanteenScreen> {
  final _loaderKey = GlobalKey<LoaderState<_CanteenView>>();
  int _tab = 0;
  String? _day;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('canteen.title')),
            ChildCard(
              name: widget.child.name,
              line: '${widget.child.className}  •  ${widget.child.code}',
              tint: tint,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: PillTabs(
                tint: tint,
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
                tabs: [
                  TabSpec(label: t('canteen.order'), icon: Icons.restaurant_rounded),
                  TabSpec(
                    label: t('canteen.orders'),
                    icon: Icons.receipt_long_rounded,
                    color: AppTheme.blue,
                  ),
                  TabSpec(
                    label: t('canteen.money'),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppTheme.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: kCardGap),
            Expanded(
              child: Loader<_CanteenView>(
                key: _loaderKey,
                tint: tint,
                watch: '${widget.child.studentId}|$_day|$_tab',
                padding: clearOfTheBar(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                load: _load,
                builder: (context, view) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BalanceCard(
                      balance: view.balance,
                      onLimit: () => _editLimit(view.balance),
                    ),
                    const SizedBox(height: kCardGap),
                    if (_tab == 0)
                      _OrderPane(
                        child: widget.child,
                        balance: view.balance,
                        menu: view.menu!,
                        onDay: (day) => setState(() => _day = day),
                        onChanged: () => _loaderKey.currentState?.reload(),
                      )
                    else if (_tab == 1)
                      _OrdersPane(
                        child: widget.child,
                        orders: view.orders ?? const [],
                        onChanged: () => _loaderKey.currentState?.reload(),
                      )
                    else
                      _MoneyPane(history: view.history ?? const []),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_CanteenView> _load() async {
    final api = ParentApi.instance;
    final id = widget.child.studentId;
    final tenant = widget.child.tenantId;

    final balance = await api.canteenBalance(id, tenantId: tenant);
    final day = _dayInRange(balance);

    return switch (_tab) {
      1 => _CanteenView(
          balance: balance,
          orders: await api.canteenOrders(id, tenantId: tenant),
        ),
      2 => _CanteenView(
          balance: balance,
          history: await api.canteenHistory(id, tenantId: tenant),
        ),
      _ => _CanteenView(
          balance: balance,
          menu: await api.canteenMenu(id, day, tenantId: tenant),
        ),
    };
  }

  String _dayInRange(CanteenBalance balance) {
    final chosen = _day;
    if (chosen == null) return balance.today;
    if (chosen.compareTo(balance.today) < 0) return balance.today;
    if (chosen.compareTo(balance.lastDayYouCanOrder) > 0) return balance.lastDayYouCanOrder;
    return chosen;
  }

  Future<void> _editLimit(CanteenBalance balance) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (_) => _LimitSheet(child: widget.child, balance: balance),
    );
    if (saved == true) _loaderKey.currentState?.reload();
  }
}

class _CanteenView {
  const _CanteenView({required this.balance, this.menu, this.orders, this.history});

  final CanteenBalance balance;
  final CanteenDayMenu? menu;
  final List<CanteenOrder>? orders;
  final List<CanteenLedgerRow>? history;
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onLimit});

  final CanteenBalance balance;
  final VoidCallback onLimit;

  @override
  Widget build(BuildContext context) {
    final tint = balance.low ? AppTheme.amber : AppTheme.green;
    final limit = balance.dailyLimitIqd;

    return Card16(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: Icons.account_balance_wallet_rounded, color: tint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('canteen.balance'),
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      iqd(balance.balanceIqd),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
              if (balance.low) StatusChip(t('canteen.runningLow'), color: AppTheme.amber),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.canvas,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 17, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('canteen.topUpAtOffice'),
                    style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TileRow(
            icon: Icons.speed_rounded,
            color: tint,
            title: t('canteen.dailyLimit'),
            trailing: limit == null ? t('canteen.noLimit') : iqd(limit),
            onTap: onLimit,
          ),
          TileRow(
            icon: Icons.alarm_rounded,
            color: AppTheme.textMuted,
            title: t('canteen.cutOff'),
            trailing: clock12(balance.cutoffMinuteOfDay),
            last: true,
          ),
        ],
      ),
    );
  }
}

class _OrderPane extends StatefulWidget {
  const _OrderPane({
    required this.child,
    required this.balance,
    required this.menu,
    required this.onDay,
    required this.onChanged,
  });

  final Child child;
  final CanteenBalance balance;
  final CanteenDayMenu menu;
  final ValueChanged<String> onDay;
  final VoidCallback onChanged;

  @override
  State<_OrderPane> createState() => _OrderPaneState();
}

class _OrderPaneState extends State<_OrderPane> {
  late Map<String, int> _wanted = _fromOrder(widget.menu.order);
  bool _busy = false;
  String? _error;

  static Map<String, int> _fromOrder(CanteenOrder? order) {
    if (order == null || !order.live) return <String, int>{};
    return {for (final line in order.lines) line.itemId: line.quantity};
  }

  @override
  void didUpdateWidget(_OrderPane old) {
    super.didUpdateWidget(old);
    if (old.menu.day != widget.menu.day || old.menu.order?.id != widget.menu.order?.id) {
      _wanted = _fromOrder(widget.menu.order);
      _error = null;
    }
  }

  int get _total {
    var sum = 0;
    for (final item in widget.menu.items) {
      sum += item.priceIqd * (_wanted[item.id] ?? 0);
    }
    return sum;
  }

  bool get _changed {
    final was = _fromOrder(widget.menu.order);
    if (was.length != _wanted.values.where((q) => q > 0).length) return true;
    for (final entry in _wanted.entries) {
      if (entry.value > 0 && was[entry.key] != entry.value) return true;
    }
    return false;
  }

  List<String> get _warnings {
    final words = <String>{};
    for (final item in widget.menu.items) {
      if ((_wanted[item.id] ?? 0) > 0) words.addAll(item.allergyWarnings);
    }
    return words.toList();
  }

  List<DateTime> get _days {
    final first = widget.balance.firstDay;
    final last = widget.balance.lastDay;
    final out = <DateTime>[];
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  Future<void> _send() async {
    final warnings = _warnings;
    if (warnings.isNotEmpty) {
      final ok = await confirmDialog(
        context,
        icon: Icons.warning_amber_rounded,
        tone: AppTheme.rose,
        title: t('canteen.allergyTitle'),
        body: tn('canteen.allergyBody', warnings.map(allergenWord).join('، ')),
        confirmLabel: t('canteen.orderAnyway'),
        confirmIcon: Icons.check_rounded,
      );
      if (!ok) return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentApi.instance.placeCanteenOrder(
        studentId: widget.child.studentId,
        day: widget.menu.day,
        quantities: _wanted,
        tenantId: widget.child.tenantId,
      );
      if (!mounted) return;
      showNote(context, t('canteen.orderPlaced'));
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(CanteenOrder order) async {
    final ok = await confirmDialog(
      context,
      icon: Icons.undo_rounded,
      tone: AppTheme.rose,
      title: t('canteen.cancelTitle'),
      body: t('canteen.cancelBody'),
      confirmLabel: t('canteen.cancelDo'),
      confirmIcon: Icons.undo_rounded,
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await ParentApi.instance.cancelCanteenOrder(
        studentId: widget.child.studentId,
        orderId: order.id,
        tenantId: widget.child.tenantId,
      );
      if (!mounted) return;
      showNote(context, t('canteen.orderCancelled'));
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final menu = widget.menu;
    final order = menu.order;
    final shut = menu.ordersClosed;
    final total = _total;
    final short = total > widget.balance.balanceIqd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 66,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final d in _days)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _DayChip(
                    date: d,
                    on: dayKeyOf(d) == menu.day,
                    onTap: () => widget.onDay(dayKeyOf(d)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: kCardGap),

        if (order != null && !order.live) ...[
          NoticeBanner(
            icon: Icons.receipt_long_rounded,
            color: orderStateTint(order.status),
            title: orderStateWord(order.status),
            body: tn('canteen.orderWas', iqd(order.totalIqd)),
          ),
          const SizedBox(height: kCardGap),
        ],

        if (shut) ...[
          NoticeBanner(
            icon: Icons.lock_clock,
            color: AppTheme.amber,
            title: t('canteen.closedTitle'),
            body: t('canteen.closedBody'),
          ),
          const SizedBox(height: kCardGap),
        ],

        if (menu.items.isEmpty)
          Card16(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                t('canteen.nothingServed'),
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
            ),
          )
        else
          for (final item in menu.items)
            Padding(
              padding: const EdgeInsets.only(bottom: kCardGap),
              child: _ItemCard(
                item: item,
                quantity: _wanted[item.id] ?? 0,
                locked: shut || _busy,
                onChanged: (q) => setState(() {
                  if (q <= 0) {
                    _wanted.remove(item.id);
                  } else {
                    _wanted[item.id] = q;
                  }
                  _error = null;
                }),
              ),
            ),

        if (menu.items.isNotEmpty) ...[
          const SizedBox(height: 4),
          Card16(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('canteen.total'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.text,
                        ),
                      ),
                    ),
                    Text(
                      iqd(total),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: short ? AppTheme.rose : AppTheme.text,
                      ),
                    ),
                  ],
                ),
                if (short) ...[
                  const SizedBox(height: 6),
                  Text(
                    t('canteen.notEnough'),
                    style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.rose),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.rose),
                  ),
                ],
                const SizedBox(height: 12),
                BigButton(
                  label: order != null && order.live
                      ? t('canteen.changeOrder')
                      : t('canteen.placeOrder'),
                  color: tint,
                  busy: _busy,
                  onPressed: shut || short || total == 0 || !_changed ? null : _send,
                ),
                if (order != null && order.changeable) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _busy ? null : () => _cancel(order),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        t('canteen.cancelOrder'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.rose,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.on, required this.onTap});

  final DateTime date;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: on ? tint : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: on ? null : Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t('dayShort.${date.weekday}'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : AppTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.quantity,
    required this.locked,
    required this.onChanged,
  });

  final CanteenMenuItem item;
  final int quantity;
  final bool locked;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final warn = item.clashesWithAllergy;
    final about = item.descriptionText;

    return Card16(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nameText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    if (about.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        about,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      iqd(item.priceIqd),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _Counter(
                value: quantity,
                locked: locked,
                onChanged: onChanged,
              ),
            ],
          ),
          if (item.allergens.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in item.allergens)
                  StatusChip(
                    allergenWord(a),
                    color: item.allergyWarnings.contains(a) ? AppTheme.rose : AppTheme.textMuted,
                  ),
              ],
            ),
          ],
          if (warn) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 15, color: AppTheme.rose),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    t('canteen.allergyWarn'),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.rose,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.locked, required this.onChanged});

  final int value;
  final bool locked;
  final ValueChanged<int> onChanged;

  static const _max = 20;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    if (value == 0) {
      return GestureDetector(
        onTap: locked ? null : () => onChanged(1),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: locked ? AppTheme.canvas : tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.add_rounded,
            size: 19,
            color: locked ? AppTheme.textFaint : tint,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Step(
          icon: Icons.remove_rounded,
          enabled: !locked,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tint),
          ),
        ),
        _Step(
          icon: Icons.add_rounded,
          enabled: !locked && value < _max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, size: 16, color: enabled ? AppTheme.text : AppTheme.textFaint),
      ),
    );
  }
}

class _OrdersPane extends StatelessWidget {
  const _OrdersPane({required this.child, required this.orders, required this.onChanged});

  final Child child;
  final List<CanteenOrder> orders;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Card16(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            t('canteen.noOrders'),
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: kCardGap),
            child: Card16(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          longDate(order.date),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      StatusChip(orderStateWord(order.status), color: orderStateTint(order.status)),
                    ],
                  ),
                  const SizedBox(height: 9),
                  for (final line in order.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '${line.quantity}×',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              line.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppTheme.text),
                            ),
                          ),
                          Text(
                            iqd(line.lineTotalIqd),
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('canteen.total'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                      ),
                      Text(
                        iqd(order.totalIqd),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MoneyPane extends StatelessWidget {
  const _MoneyPane({required this.history});

  final List<CanteenLedgerRow> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Card16(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            t('canteen.noMoves'),
            style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        children: [
          for (final row in history)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: (row.addsMoney ? AppTheme.green : AppTheme.blue)
                          .withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      row.addsMoney ? Icons.add_rounded : Icons.restaurant_rounded,
                      size: 16,
                      color: row.addsMoney ? AppTheme.green : AppTheme.blue,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ledgerWord(row.kind),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.text,
                          ),
                        ),
                        Text(
                          shortDate(row.at),
                          style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${row.addsMoney ? '+' : '−'}${iqd(row.amountIqd.abs())}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: row.addsMoney ? AppTheme.green : AppTheme.text,
                        ),
                      ),
                      Text(
                        iqd(row.balanceAfterIqd),
                        style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LimitSheet extends StatefulWidget {
  const _LimitSheet({required this.child, required this.balance});

  final Child child;
  final CanteenBalance balance;

  @override
  State<_LimitSheet> createState() => _LimitSheetState();
}

class _LimitSheetState extends State<_LimitSheet> {
  late bool _capped = widget.balance.dailyLimitIqd != null;
  late final TextEditingController _amount =
      TextEditingController(text: '${widget.balance.dailyLimitIqd ?? ''}');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final typed = int.tryParse(_amount.text.trim());
    if (_capped && (typed == null || typed < 0)) {
      setState(() => _error = t('canteen.limitBadNumber'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ParentApi.instance.setCanteenDailyLimit(
        studentId: widget.child.studentId,
        dailyLimitIqd: _capped ? typed : null,
        tenantId: widget.child.tenantId,
      );
      if (!mounted) return;
      showNote(context, t('canteen.limitSaved'));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: withBottomInset(context, const EdgeInsets.fromLTRB(18, 10, 18, 18)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('canteen.dailyLimit'),
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                t('canteen.limitBlurb'),
                style: TextStyle(fontSize: 12.5, height: 1.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: _capped,
                onChanged: (v) => setState(() {
                  _capped = v;
                  _error = null;
                }),
                activeThumbColor: tint,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t('canteen.limitOn'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
              ),
              if (_capped) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: t('canteen.limitHint'),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(fontSize: 12, color: AppTheme.rose)),
              ],
              const SizedBox(height: 16),
              BigButton(
                label: t('common.save'),
                color: tint,
                busy: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
