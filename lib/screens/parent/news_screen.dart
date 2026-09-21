import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.child});

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
            const _Heading(),
            Expanded(
              child: Loader<List<NewsPost>>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
                load: () => ParentApi.instance.news(child.studentId),
                isEmpty: (posts) => posts.isEmpty,
                empty: t('news.none'),
                builder: (context, posts) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in posts) ...[
                      _Post(post: p, tint: tint),
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
                  t('news.title'),
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
                  t('news.subtitle'),
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

class _Post extends StatelessWidget {
  const _Post({required this.post, required this.tint});

  final NewsPost post;
  final Color tint;

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _Viewer(post: post, index: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campus = post.campusName;
    final when = post.publishedAt;

    return Card16(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: Icons.campaign_outlined, color: tint, size: 30),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (when != null)
                      Text(
                        '${when.day} ${t('monthShort.${when.month}')} ${when.year}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: tint,
                        ),
                      ),
                    if (campus != null && campus.isNotEmpty) ...[
                      const SizedBox(height: 3),
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
              if (post.photos.isNotEmpty) ...[
                const SizedBox(width: 9),
                _CountChip(count: post.photos.length, tint: tint),
              ],
            ],
          ),

          if (post.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.text,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.text),
            ),
          ],

          if (post.photos.isNotEmpty) ...[
            const SizedBox(height: 11),
            _Grid(post: post, onOpen: (i) => _open(context, i)),
          ],
        ],
      ),
    );
  }
}

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

class _Grid extends StatelessWidget {
  const _Grid({required this.post, required this.onOpen});

  final NewsPost post;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    if (post.photos.length == 1) {
      return GestureDetector(
        onTap: () => onOpen(0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: post.photos.first.aspect.clamp(0.75, 1.9),
            child: _Thumb(photo: post.photos.first),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
      ),
      itemCount: post.photos.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => onOpen(i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _Thumb(photo: post.photos[i]),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo});

  final NewsPhoto photo;

  @override
  Widget build(BuildContext context) {
    final url = photo.thumbnailUrl;
    if (url == null) return const _Placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, widget, progress) =>
          progress == null ? widget : const _Placeholder(),
      errorBuilder: (_, _, _) => const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppTheme.neutralSoft,
        child: Center(
          child: Icon(Icons.image_outlined, size: 22, color: AppTheme.textFaint),
        ),
      );
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.post, required this.index});

  final NewsPost post;
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
    final caption = widget.post.text;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overDarkMedia,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.post.photos.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, i) => _PhotoPage(photo: widget.post.photos[i]),
            ),

            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: SafeArea(
                bottom: false,
                minimum: const EdgeInsets.fromLTRB(10, 6, 10, 0),
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
                        '${_current + 1} / ${widget.post.photos.length}',
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
            ),

            if (caption.isNotEmpty)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    18 + MediaQuery.paddingOf(context).left,
                    22,
                    18 + MediaQuery.paddingOf(context).right,
                    MediaQuery.paddingOf(context).bottom + 20,
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
                    caption,
                    textAlign: TextAlign.start,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _PhotoPage extends StatelessWidget {
  const _PhotoPage({required this.photo});

  final NewsPhoto photo;

  @override
  Widget build(BuildContext context) {
    final url = photo.url;
    if (url == null) return const SizedBox.shrink();
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Image.network(
          url,
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
