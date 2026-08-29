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
  const SplashGate({super.key, required this.child});

  final Widget child;

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

  VideoPlayerController? _video;
  bool _done = false;
  Timer? _deadline;

  @override
  void initState() {
    super.initState();
    _deadline = Timer(_limit, _finish);
    _start(_asset);
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
      _finish();
      return;
    }
    if (value.duration > Duration.zero && value.position >= value.duration) {
      _finish();
    }
  }

  void _finish() {
    if (_done) return;
    _done = true;
    _deadline?.cancel();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _deadline?.cancel();
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
        // Faded out rather than removed, so the last frame of the clip melts
        // into whichever screen the gate settled on instead of cutting to it.
        IgnorePointer(
          ignoring: _done,
          child: AnimatedOpacity(
            opacity: _done ? 0 : 1,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOut,
            child: _Curtain(video: _video),
          ),
        ),
      ],
    );
  }
}

class _Curtain extends StatelessWidget {
  const _Curtain({required this.video});

  final VideoPlayerController? video;

  @override
  Widget build(BuildContext context) {
    final ready = video != null && video!.value.isInitialized;

    // Before the first frame decodes there is nothing to show — but it still
    // has to cover the app, or the screen underneath flashes through.
    if (!ready) {
      return const SizedBox.expand(child: ColoredBox(color: Color(0xFF6D3FF7)));
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
