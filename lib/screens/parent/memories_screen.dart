import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/screen_kit.dart';

/// Photographs and clips of one child at school.
///
/// Grouped by the day rather than served as a wall of images: a family looking
/// at these is looking at a day — the sports day, the trip to the museum — and
/// the title and the date are most of what makes them worth keeping.
///
/// Every frame here has already passed the consent check on the server. The
/// child is in it, and so is nobody whose family declined. Nothing is filtered
/// again on this side, because a rule enforced in two places is a rule that
/// eventually disagrees with itself.
class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key, required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('memories.title'), onBell: () {}),
            Expanded(
              child: Loader<List<MemoryAlbum>>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: () => ParentApi.instance.memories(child.studentId),
                isEmpty: (albums) => albums.isEmpty,
                empty: t('memories.none'),
                builder: (context, albums) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in albums) ...[
                      _Album(album: a, tint: tint),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Album extends StatelessWidget {
  const _Album({required this.album, required this.tint});

  final MemoryAlbum album;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                    album.title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [longDate(album.happenedOn), album.campusName]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusChip('${album.items.length}', color: tint),
          ],
        ),
        if (album.description != null && album.description!.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            album.description!,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.textMuted),
          ),
        ],
        const SizedBox(height: 11),
        _Grid(album: album),
      ],
    );
  }
}

/// Three across, square.
///
/// Not a staggered layout: the pictures come from a dozen different handsets in
/// portrait and landscape, and a grid that reflows around them turns a page of
/// memories into a puzzle. Square thumbnails, real proportions when opened.
class _Grid extends StatelessWidget {
  const _Grid({required this.album});

  final MemoryAlbum album;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: album.items.length,
      itemBuilder: (context, i) => _Thumb(
        item: album.items[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _Viewer(album: album, index: i),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.onTap});

  final MemoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(13),
          border: AppTheme.dark ? Border.all(color: AppTheme.border) : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.thumbnailUrl != null)
              Image.network(
                item.thumbnailUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, widget, progress) =>
                    progress == null ? widget : const _Placeholder(),
                errorBuilder: (_, _, _) => const _Placeholder(),
              )
            else
              const _Placeholder(),

            // A clip needs to say so before it is tapped, or a parent on a
            // school connection waits on a still that was never going to move.
            if (item.isVideo)
              Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppTheme.dark ? const Color(0xFF1A2233) : const Color(0xFFF1F2F6),
        child: Center(
          child: Icon(Icons.image_outlined, size: 22, color: AppTheme.textFaint),
        ),
      );
}

/* ---------------------------------------------------------------------------
 * Full screen
 * ------------------------------------------------------------------------- */

class _Viewer extends StatefulWidget {
  const _Viewer({required this.album, required this.index});

  final MemoryAlbum album;
  final int index;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController _pages = PageController(initialPage: widget.index);
  late int _current = widget.index;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.album.items[_current];

    // Black, whatever the app theme is. A photograph is the thing on screen and
    // a pale surround changes how it reads.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.album.items.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              final it = widget.album.items[i];
              return it.isVideo
                  ? _VideoPage(key: ValueKey(it.id), item: it)
                  : _PhotoPage(item: it);
            },
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 10,
            right: 10,
            child: Row(
              children: [
                _RoundButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_current + 1} / ${widget.album.items.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (item.caption != null && item.caption!.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  18,
                  22,
                  18,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
                child: Text(
                  item.caption!,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.item});

  final MemoryItem item;

  @override
  Widget build(BuildContext context) {
    if (item.url == null) return const SizedBox.shrink();
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.network(
          item.url!,
          fit: BoxFit.contain,
          loadingBuilder: (context, widget, progress) => progress == null
              ? widget
              : const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white54),
                ),
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white38),
          ),
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({super.key, required this.item});

  final MemoryItem item;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.item.url;
    if (url == null) {
      _failed = true;
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    c
        .initialize()
        .then((_) {
          if (!mounted) return;
          c.setLooping(true);
          c.play();
          setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    if (_failed) {
      return const Center(
        child: Icon(Icons.videocam_off_outlined, size: 40, color: Colors.white38),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white54),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 21, color: Colors.white),
      ),
    );
  }
}
