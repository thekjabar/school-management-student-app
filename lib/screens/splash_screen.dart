import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../ui/motion.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.child,
    required this.tint,
    this.ready,
  });

  final Widget child;

  final Color tint;

  final Future<void>? ready;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  static const _asset = 'assets/video/splash.mp4';

  static const _limit = Duration(seconds: 12);

  static const _fade = Duration(milliseconds: 420);

  VideoPlayerController? _video;
  bool _done = false;
  bool _clipOver = false;
  bool _appReady = false;
  bool _curtainGone = false;
  Timer? _deadline;
  Timer? _settle;
  Timer? _duck;

  @override
  void initState() {
    super.initState();
    appRevealed.value = false;
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

  void _mark({bool clip = false, bool ready = false}) {
    if (clip) _clipOver = true;
    if (ready) _appReady = true;
    if (_clipOver && _appReady) _finish();
  }

  Future<void> _start(String asset) async {
    final video = VideoPlayerController.asset(asset);
    try {
      await video.initialize();
      if (!mounted || _done) {
        await video.dispose();
        return;
      }
      setState(() => _video = video);
      video.addListener(_watch);
      await video.play();
    } catch (_) {
      await video.dispose();
      _finish();
    }
  }

  void _watch() {
    final video = _video;
    if (video == null || _done) return;
    final value = video.value;
    if (value.hasError) {
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
    if (!mounted) return;
    setState(() {});
    _fadeSound();

    _settle = Timer(_fade + const Duration(milliseconds: 40), () {
      _release();
      if (mounted) setState(() => _curtainGone = true);
    });

    Timer(_fade ~/ 3, () => appRevealed.value = true);
  }

  void _fadeSound() {
    final video = _video;
    if (video == null) return;

    const step = Duration(milliseconds: 20);
    final steps = _fade.inMilliseconds ~/ step.inMilliseconds;
    var done = 0;

    _duck?.cancel();
    _duck = Timer.periodic(step, (timer) {
      done++;
      final left = (1 - done / steps).clamp(0.0, 1.0);
      _video?.setVolume(left * left);
      if (done >= steps) timer.cancel();
    });
  }

  void _release() {
    _duck?.cancel();
    final video = _video;
    if (video == null) return;
    _video = null;
    video.removeListener(_watch);
    video.pause();
    video.dispose();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _settle?.cancel();
    _duck?.cancel();
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
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

  final Color tint;

  @override
  Widget build(BuildContext context) {
    final ready = video != null && video!.value.isInitialized;

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

        final wide = aspect > screen;
        final width = wide ? box.maxWidth : box.maxHeight * aspect;
        final height = wide ? box.maxWidth / aspect : box.maxHeight;

        return ColoredBox(
          color: const Color(0xFF6D3FF7),
          child: Stack(
            fit: StackFit.expand,
            children: [
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
