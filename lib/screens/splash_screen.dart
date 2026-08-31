import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The opening clip, played once over the app while it starts up.
///
/// The app underneath is built and running from the first frame — the splash is
/// a lid, not a stage. That way the clip is spending time the sign-in check was
/// going to spend anyway, rather than adding its length to how long the app
/// takes to open.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    required this.tint,
    this.ready,
  });

  final Widget child;

  /// The colour behind the clip, and under it before the first frame decodes.
  ///
  /// Passed in rather than read from a global. This used to be the parent tint
  /// written as a hex literal, so opening the DRIVER app began with a flash of
  /// the parent app's violet before the driver's own clip appeared.
  final Color tint;

  /// Completes when the app underneath has what it needs to draw a real
  /// screen. The curtain lifts once this has landed AND the clip has had its
  /// moment, so a fast connection never sees a second loading screen and a
  /// slow one spends the wait watching the clip rather than a spinner.
  ///
  /// Null means "do not wait" — the clip alone decides.
  final Future<void>? ready;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  /// One name, whichever app this is. tool/build_apks.sh copies the role's
  /// clip here before the build — see the note there for why it is not four
  /// asset entries.
  static const _asset = 'assets/video/splash.mp4';

  /// Nothing waits for ever. A codec a handset cannot open, a file that fails
  /// to decode, a device with video disabled — every one of those used to be a
  /// permanently black first screen in apps that do this, and the fix is a
  /// deadline rather than a list of cases.
  static const _limit = Duration(seconds: 6);

  /// The shortest the clip is allowed to hold the screen, measured from the
  /// moment its first frame is up.
  ///
  /// This gate used to wait for the WHOLE clip. The parent clip runs just over
  /// five seconds and the sign-in check lands in about one, so the app spent
  /// nearly four seconds of every launch finished and idle behind an opaque
  /// video. Worse, it made the home screen's skeleton unreachable: the skeleton
  /// exists so a slow connection sees the shell filling in rather than a blank,
  /// and the clip outlasted it every time, so it could never once be seen.
  ///
  /// So the clip is a floor rather than a duration — on screen long enough to
  /// read as deliberate instead of a flash, then out of the way the moment the
  /// app is ready.
  ///
  /// Timed from the first frame rather than from startup, because opening a
  /// 15MB clip on a cold cheap handset is not instant. Started at startup, a
  /// slow decode would spend the floor on the flat tint and then show a
  /// fraction of a second of video before cutting — which looks like a fault,
  /// not a splash. This way the clip always gets its moment.
  static const _floor = Duration(milliseconds: 1900);

  /// How long the curtain takes to fade out.
  static const _fade = Duration(milliseconds: 420);

  VideoPlayerController? _video;
  bool _done = false;
  bool _clipOver = false;
  bool _appReady = false;
  bool _floorOver = false;
  bool _curtainGone = false;
  Timer? _deadline;
  Timer? _minimum;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    // The deadline is the backstop for both halves. A codec the handset cannot
    // open used to be a permanently black screen; a server that never answers
    // would now be the same thing, and one rule covers both.
    _deadline = Timer(_limit, _finish);
    _start(_asset);

    if (widget.ready == null) {
      _appReady = true;
    } else {
      widget.ready!
          .then((_) => _mark(ready: true))
          .catchError((_) => _mark(ready: true));
    }
  }

  /// Lift once the app is ready AND the clip has had its moment — whichever
  /// comes first of the floor and the clip's own end, so a clip shorter than
  /// the floor is never padded out with a frozen last frame.
  void _mark({bool clip = false, bool ready = false, bool floor = false}) {
    if (clip) _clipOver = true;
    if (ready) _appReady = true;
    if (floor) _floorOver = true;
    if (_appReady && (_floorOver || _clipOver)) _finish();
  }

  Future<void> _start(String asset) async {
    final video = VideoPlayerController.asset(asset);
    try {
      await video.initialize();
      if (!mounted) {
        await video.dispose();
        return;
      }
      setState(() => _video = video);
      // The floor starts here, with a frame decoded and about to be painted —
      // not back in initState, where a slow open would have eaten it.
      _minimum = Timer(_floor, () => _mark(floor: true));
      video.addListener(_watch);
      await video.play();
    } catch (_) {
      await video.dispose();
      _finish();
    }
  }

  /// The controller has no "finished" callback, so the end of the clip is the
  /// position reaching the duration with playback stopped.
  void _watch() {
    final video = _video;
    if (video == null || _done) return;
    final value = video.value;
    if (value.hasError) {
      // A broken clip must not hold the app hostage waiting for the other half.
      _finish();
      return;
    }
    if (value.duration > Duration.zero && value.position >= value.duration) {
      _mark(clip: true);
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _deadline?.cancel();
    _minimum?.cancel();
    // Nothing below is worth doing for a gate that is already off screen —
    // dispose has cancelled the timers and let go of the controller, and a
    // settle timer armed after that point is a leak that outlives the widget.
    if (!mounted) return;
    setState(() {});

    // The curtain fades rather than vanishing, so the clip carries on decoding
    // behind a transparent layer while the home screen draws its first frames —
    // on a cheap handset, a video decoder competing with the one screen whose
    // smoothness anybody will remember. Now that the clip is no longer played
    // to its end, that tail is seconds long rather than nothing.
    //
    // Once the fade is over the clip has nothing left to show: stop it, and
    // take it out of the tree.
    _settle = Timer(_fade + const Duration(milliseconds: 40), () {
      _video?.pause();
      if (mounted) setState(() => _curtainGone = true);
    });
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _minimum?.cancel();
    _settle?.cancel();
    _video?.removeListener(_watch);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Every child gets tight constraints. Without this the curtain was laid
      // out loose, FittedBox sized itself to the clip's aspect ratio rather
      // than to the screen — that is what
      // constrainSizeAndAttemptToPreserveAspectRatio does — and a 9:16 clip on
      // a 9:19.5 phone left a quarter of the app showing underneath, bottom
      // bar and all.
      fit: StackFit.expand,
      children: [
        widget.child,
        // Faded out rather than cut, so the clip melts into whichever screen
        // the gate settled on — then dropped entirely once the fade is done,
        // because a fully transparent video layer still composites and still
        // decodes.
        if (!_curtainGone)
          IgnorePointer(
            ignoring: _done,
            child: AnimatedOpacity(
              opacity: _done ? 0 : 1,
              duration: _fade,
              curve: Curves.easeOut,
              child: _Curtain(video: _video, tint: widget.tint),
            ),
          ),
      ],
    );
  }
}

class _Curtain extends StatelessWidget {
  const _Curtain({required this.video, required this.tint});

  final VideoPlayerController? video;

  /// The role's own colour, behind and around the clip.
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ready = video != null && video!.value.isInitialized;

    // Before the first frame decodes there is nothing to show — but it still
    // has to cover the app, or the screen underneath flashes through.
    if (!ready) {
      return SizedBox.expand(child: ColoredBox(color: tint));
    }

    final frame = SizedBox(
      width: video!.value.size.width,
      height: video!.value.size.height,
      child: VideoPlayer(video!),
    );
    final aspect = video!.value.aspectRatio;

    return LayoutBuilder(
      builder: (context, box) {
        final screen = box.maxWidth / box.maxHeight;

        // How much of the frame survives filling the screen with it. A portrait
        // master loses a fifth off the sides, which nobody notices; a 16:9 clip
        // loses three quarters, which is not a splash screen, it is a close-up.
        final kept = (aspect < screen ? aspect / screen : screen / aspect);
        final fills = kept >= 0.78;

        if (fills) {
          return SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: ClipRect(
              child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: frame),
            ),
          );
        }

        // Otherwise the clip shows whole, as large as its shape allows, and
        // everything outside it is the same clip blown up and blurred — a
        // backdrop rather than a letterbox, which is the only version of this
        // that looks deliberate. A portrait master removes the need for it.
        final wide = aspect > screen;
        final width = wide ? box.maxWidth : box.maxHeight * aspect;
        final height = wide ? box.maxWidth / aspect : box.maxHeight;

        return ColoredBox(
          color: const Color(0xFF6D3FF7),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // One controller, two VideoPlayers: both draw the same texture,
              // so this costs a second composite rather than a second decode.
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34, tileMode: TileMode.clamp),
                child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: frame),
              ),
              const ColoredBox(color: Color(0x33000000)),
              Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: frame),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
