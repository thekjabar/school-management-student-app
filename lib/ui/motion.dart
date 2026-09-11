import 'package:flutter/material.dart';

bool motionOff(BuildContext context) => MediaQuery.disableAnimationsOf(context);

final ValueNotifier<bool> appRevealed = ValueNotifier<bool>(true);

VoidCallback? whenRevealed(VoidCallback start) {
  if (appRevealed.value) {
    start();
    return null;
  }
  late final VoidCallback listener;
  listener = () {
    if (!appRevealed.value) return;
    appRevealed.removeListener(listener);
    start();
  };
  appRevealed.addListener(listener);
  return listener;
}

const kStaggerStep = Duration(milliseconds: 50);

const kStaggerCap = Duration(milliseconds: 260);

Duration staggerDelay(int index, {Duration extra = Duration.zero}) {
  final own = kStaggerStep * (index < 0 ? 0 : index);
  return (own > kStaggerCap ? kStaggerCap : own) + extra;
}

class Rise extends StatefulWidget {
  const Rise({
    super.key,
    required this.child,
    this.index = 0,
    this.extraDelay = Duration.zero,
    this.distance = 10,
    this.duration = const Duration(milliseconds: 380),
  });

  final Widget child;

  final int index;

  final Duration extraDelay;

  final double distance;

  final Duration duration;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final Duration _delay = staggerDelay(widget.index, extra: widget.extraDelay);
  late final Duration _total = _delay + widget.duration;
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _total);
  late final CurvedAnimation _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _total.inMicroseconds == 0 ? 0 : _delay.inMicroseconds / _total.inMicroseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  bool _played = false;
  bool _still = false;
  VoidCallback? _waiting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = motionOff(context);
    if (_played) return;
    _played = true;
    if (_still) {
      _controller.value = 1;
      return;
    }
    _waiting = whenRevealed(() {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    if (_waiting != null) appRevealed.removeListener(_waiting!);
    _t.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, widget.distance * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

class Pop extends StatefulWidget {
  const Pop({
    super.key,
    required this.child,
    this.index = 0,
    this.extraDelay = Duration.zero,
    this.from = 0.7,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final int index;
  final Duration extraDelay;

  final double from;

  final Duration duration;

  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends State<Pop> with SingleTickerProviderStateMixin {
  late final Duration _delay = staggerDelay(widget.index, extra: widget.extraDelay);
  late final Duration _total = _delay + widget.duration;
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _total);

  late final CurvedAnimation _t = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _total.inMicroseconds == 0 ? 0 : _delay.inMicroseconds / _total.inMicroseconds,
      1,
      curve: Curves.easeOutBack,
    ),
  );

  bool _played = false;
  bool _still = false;
  VoidCallback? _waiting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = motionOff(context);
    if (_played) return;
    _played = true;
    if (_still) {
      _controller.value = 1;
      return;
    }
    _waiting = whenRevealed(() {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    if (_waiting != null) appRevealed.removeListener(_waiting!);
    _t.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale: widget.from + (1 - widget.from) * _t.value,
        child: child,
      ),
    );
  }
}

class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    if (motionOff(context)) return builder(context, value);
    return ValueListenableBuilder<bool>(
      valueListenable: appRevealed,
      builder: (context, revealed, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: revealed ? value : 0),
        duration: duration,
        curve: curve,
        builder: (context, shown, _) => builder(context, shown),
      ),
    );
  }
}
