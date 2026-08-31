import 'package:flutter/material.dart';

/// The app's entire motion vocabulary: three entrances and a counter.
///
/// Deliberately four things rather than a framework. Everything here is an
/// ENTRANCE — it plays once, when a screen appears, and then the pixels are
/// still. Nothing in this file loops, and nothing may be given a `repeat()`: a
/// permanently breathing icon is charming on the first viewing, noise on the
/// tenth, and a battery cost on the hundredth.
///
/// Three rules hold the whole file together, and they are enforced HERE rather
/// than at the call sites so that no call site can forget them:
///
///  1. [motionOff] is read by every widget below. When the phone has asked for
///     less motion — an accessibility setting for some people, a battery
///     setting on some devices — each widget renders its final state on the
///     first frame and never starts a controller at all.
///  2. Motion plays once per ELEMENT, not once per build. Each entrance starts
///     its controller in `didChangeDependencies`, behind a `_played` latch that
///     is never cleared, and `didUpdateWidget` is deliberately not implemented.
///     A parent that rebuilds — a `Loader` refetching, a poll calling
///     `reload(quiet: true)`, the theme flipping — replaces the widget but not
///     the element, so the entrance does not replay and the screen does not
///     twitch every few seconds forever.
///  3. Every controller is disposed, and nothing here calls `setState` at all,
///     so nothing here can call it after the widget is gone.

/// Whether this device has asked for stillness.
///
/// The one place the setting is read. Everything below funnels through it.
bool motionOff(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Whether the app is actually being looked at yet.
///
/// The splash is a lid over an app that is already running — that is the whole
/// point of it, and it is why the app opens as fast as it does. But it means
/// the shell mounts on the first frame and the home screen builds itself
/// underneath an opaque video.
///
/// Every entrance below keys off mounting. So all of it started, ran and
/// FINISHED behind the curtain, and the curtain lifted onto a screen that had
/// already settled. The motion was real, it ran every launch, and not one frame
/// of it was ever visible — which is why the app looked static however much was
/// added to it.
///
/// Starts true, because an app with nothing covering it is being looked at.
/// [SplashGate] sets it false while its curtain is down.
final ValueNotifier<bool> appRevealed = ValueNotifier<bool>(true);

/// Runs [start] once the app is on screen — now, if it already is.
///
/// Returns the listener to hand back to [ValueNotifier.removeListener] in
/// dispose, or null when it fired immediately and registered nothing.
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

/// How far apart two neighbours in a staggered run start.
const kStaggerStep = Duration(milliseconds: 50);

/// The furthest into a run anything is allowed to start.
///
/// A stagger that outlasts somebody's patience is worse than none, so the
/// eleventh tile in a row does not wait eleven steps: past this point they
/// arrive together. With the default entrance the last item of a run of any
/// length is finished inside 650ms.
const kStaggerCap = Duration(milliseconds: 260);

/// When item [index] of a staggered run starts.
Duration staggerDelay(int index, {Duration extra = Duration.zero}) {
  final own = kStaggerStep * (index < 0 ? 0 : index);
  return (own > kStaggerCap ? kStaggerCap : own) + extra;
}

/// Fades in while moving up a few points.
///
/// The default entrance for a card, a row, or one column of a strip. Give
/// neighbours an ascending [index] and they arrive in order.
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

  /// Position in a staggered run. 0 — the default — starts immediately.
  final int index;

  /// Held back this much on top of the stagger, for something that should land
  /// just after whatever contains it.
  final Duration extraDelay;

  /// How far below its resting place it starts, in logical pixels. Vertical
  /// only, so there is nothing here to mirror in an RTL layout.
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

  /// Latched on the first dependency pass and never cleared. This — together
  /// with the absence of a `didUpdateWidget` — is what makes the entrance play
  /// when the screen APPEARS rather than every time something rebuilds it.
  bool _played = false;
  bool _still = false;
  VoidCallback? _waiting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = motionOff(context);
    if (_played) return;
    _played = true;
    // The controller is only ever touched on this first pass: the builder below
    // has not been mounted yet, so there is no listener here to mark dirty in
    // the middle of somebody else's build.
    if (_still) {
      _controller.value = 1;
      return;
    }
    // Held until the splash is out of the way. Mounting is not the same thing
    // as being seen, and this used to run its whole entrance behind the clip.
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

/// Scales a glyph up into place with a slight overshoot, so it lands rather
/// than blinks.
///
/// Scale only, no fade: everywhere this is used it sits inside a [Rise] that is
/// already fading, and a second [Opacity] layer over a 22px icon buys a
/// `saveLayer` every frame for a difference nobody can see.
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

  /// The scale it starts at.
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

  /// easeOutBack overshoots a little past 1, which is the whole point: the
  /// glyph arrives fractionally large and settles.
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
    // Held until the splash is out of the way — see [appRevealed].
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

/// Runs a number up to its value, and re-runs it from wherever it already is
/// when the value changes.
///
/// A [TweenAnimationBuilder] rather than a controller precisely because of what
/// it does NOT do: it animates when the tween's END moves and sits still
/// otherwise, so a rebuild carrying the same number is not an animation. The
/// first build counts from zero; a later change counts from the old number to
/// the new one rather than dropping back to zero and climbing again.
///
/// This is the only thing here that runs on data, and it animates a figure the
/// screen already has. It must never be used to imply something is happening.
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
    // The TARGET waits, rather than the animation: held at zero until the app
    // is on screen, then the change of end value is what drives the count. A
    // TweenAnimationBuilder starts the moment it is built, so behind the splash
    // this used to finish counting before anybody could see a digit move.
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
