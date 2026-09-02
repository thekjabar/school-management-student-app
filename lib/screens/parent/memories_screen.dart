import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';

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
            // The heading carries the back arrow itself rather than sitting
            // under a ScreenHeader that says the same two words a second time.
            // It is outside the Loader on purpose: it stays put over the
            // waiting blocks, over the failure panel and over "nothing yet",
            // which is the one state where a parent most needs telling which
            // page they are on.
            const _Heading(),
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
                      const SizedBox(height: kCardGap),
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

/// Back, the page's name, and the school.
///
/// The illustration is the same building that fronts the profile tab, at a
/// size where it reads as a mark beside the title rather than as a picture
/// competing with the photographs below it.
class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 6, kGutter, 12),
      child: Row(
        children: [
          SquareButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('memories.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    height: 1.1,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t('memories.subtitle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset('assets/art/school_shield.png', width: 104),
        ],
      ),
    );
  }
}

/// One day, on one card.
class _Album extends StatelessWidget {
  const _Album({required this.album, required this.tint});

  final MemoryAlbum album;
  final Color tint;

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _Viewer(album: album, index: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = album.description;
    final campus = album.campusName;

    return Card16(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // No date block at all when the server sent no date, rather than
              // a tinted box with three dashes in it.
              if (album.happenedOn != null) ...[
                _DateBlock(date: album.happenedOn!, tint: tint),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip36(icon: Icons.collections_rounded, color: tint, size: 30),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            album.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.2,
                              color: AppTheme.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (campus != null && campus.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 13, color: AppTheme.textFaint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              campus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 9),
              _CountChip(count: album.items.length, tint: tint),
            ],
          ),

          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              description,
              style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
            ),
          ],

          if (album.items.isNotEmpty) ...[
            const SizedBox(height: 11),
            _Grid(album: album, onOpen: (i) => _open(context, i)),
            const SizedBox(height: 11),
            Divider(height: 1, color: AppTheme.border),
            // A heart and a like count sit on the left of this row in the
            // design. Neither exists on this platform — no field on the album,
            // no endpoint, nowhere to record a tap — so the footer carries only
            // the half of it that goes somewhere real.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: GestureDetector(
                onTap: () => _open(context, 0),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 0, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t('memories.viewAll'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: tint,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: tint),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The day, stacked: 20, SEP, 2026.
///
/// A date said this way is read at a glance and takes a fifth of the width of
/// "Thursday 20 September 2026", which is width the title needs more.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.tint});

  final DateTime date;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.11),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            maxLines: 1,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.05,
              color: tint,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            // A chip the width of the day number under it, so the short
            // phrase rather than the whole month name.
            t('monthShort.${date.month}').toUpperCase(),
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              height: 1.2,
              color: tint,
            ),
          ),
          Text(
            '${date.year}',
            maxLines: 1,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// How many frames the album holds.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.tint});

  final int count;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 9, 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: AppTheme.dark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 12.5, color: tint),
          const SizedBox(width: 4),
          Text(
            '$count',
            maxLines: 1,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: tint),
          ),
        ],
      ),
    );
  }
}

/// Three across, square.
///
/// Not a staggered layout: the pictures come from a dozen different handsets in
/// portrait and landscape, and a grid that reflows around them turns a page of
/// memories into a puzzle. Square thumbnails, real proportions when opened.
class _Grid extends StatelessWidget {
  const _Grid({required this.album, required this.onOpen});

  final MemoryAlbum album;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
      ),
      itemCount: album.items.length,
      itemBuilder: (context, i) => _Thumb(item: album.items[i], onTap: () => onOpen(i)),
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
          color: AppTheme.neutralSoft,
          borderRadius: BorderRadius.circular(14),
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
        // The theme's own neutral, not a hardcoded grey: a light grey block
        // behind every unloaded thumbnail is a near-white hole on the dark
        // canvas.
        color: AppTheme.neutralSoft,
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

          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 6,
            start: 10,
            end: 10,
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
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsetsDirectional.fromSTEB(
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
                  textAlign: TextAlign.start,
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
