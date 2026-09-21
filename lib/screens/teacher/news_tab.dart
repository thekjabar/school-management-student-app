import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/teacher_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/format.dart';
import '../../ui/home_kit.dart';
import '../../ui/insets.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import 'teacher_kit.dart';

class TeacherNewsScreen extends StatelessWidget {
  const TeacherNewsScreen({super.key, required this.rights});

  final TeacherNewsRights rights;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Heading(
              title: t('teacher.news'),
              subtitle: t('teacher.newsSubtitle'),
              action: SquareButton(
                icon: Icons.add_rounded,
                onTap: () => _write(context),
              ),
            ),
            Expanded(
              child: Loader<List<TeacherNewsSummary>>(
                tint: tint,
                padding: withBottomInset(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                load: () => TeacherApi.instance.myNews(),
                isEmpty: (rows) => rows.isEmpty,
                empty: t('teacher.newsNone'),
                builder: (context, rows) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in rows) ...[
                      _PostRow(post: row, onOpen: () => _open(context, row.id)),
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

  void _write(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TeacherNewsEditor(rights: rights)),
    );
  }

  void _open(BuildContext context, String id) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TeacherNewsEditor(rights: rights, postId: id)),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    height: 1.15,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, height: 1.35, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.onOpen});

  final TeacherNewsSummary post;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;

    return Card16(
      padding: const EdgeInsets.all(14),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip36(icon: Icons.campaign_outlined, color: tint, size: 30),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  post.published
                      ? '${t('teacher.newsLive')} · ${longDate(post.publishedAt)}'
                      : t('teacher.newsDraft'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: post.published ? tint : AppTheme.textFaint,
                  ),
                ),
              ),
              if (post.photoCount > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.image_outlined, size: 13, color: AppTheme.textFaint),
                const SizedBox(width: 3),
                Text(
                  '${post.photoCount}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textFaint),
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Text(
            post.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.text),
          ),
          const SizedBox(height: 7),
          Text(
            tn('teacher.newsClassCount', post.classCount),
            style: TextStyle(fontSize: 11, color: AppTheme.textFaint),
          ),
          if (post.hiddenPhotoCount > 0) ...[
            const SizedBox(height: 5),
            Text(
              tn('teacher.newsWithheldCount', post.hiddenPhotoCount),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.amber),
            ),
          ],
        ],
      ),
    );
  }
}

class TeacherNewsEditor extends StatefulWidget {
  const TeacherNewsEditor({super.key, required this.rights, this.postId});

  final TeacherNewsRights rights;
  final String? postId;

  @override
  State<TeacherNewsEditor> createState() => _TeacherNewsEditorState();
}

class _TeacherNewsEditorState extends State<TeacherNewsEditor> {
  final TextEditingController _text = TextEditingController();
  final Set<String> _classIds = {};

  String? _postId;
  bool _published = false;
  List<TeacherNewsPhoto> _photos = const [];
  List<TeacherNewsChild> _children = const [];

  bool _loading = false;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _postId = widget.postId;
    if (_postId != null) _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _postId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final post = await TeacherApi.instance.newsPost(id);
      final children = await TeacherApi.instance.newsPostChildren(id);
      if (!mounted) return;
      setState(() {
        _text.text = post.text;
        _classIds
          ..clear()
          ..addAll(post.classIds);
        _published = post.published;
        _photos = post.photos;
        _children = children;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorText(e);
      });
    }
  }

  Future<String?> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _error = t('teacher.newsTextEmpty'));
      return null;
    }
    if (_classIds.isEmpty) {
      setState(() => _error = t('teacher.newsPickClass'));
      return null;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = _postId;
      if (id == null) {
        final made = await TeacherApi.instance.writeNews(text: text, classIds: _classIds.toList());
        if (!mounted) return made;
        setState(() => _postId = made);
        await _load();
        return made;
      }
      await TeacherApi.instance.reviseNews(id, text: text, classIds: _classIds.toList());
      if (!mounted) return id;
      await _load();
      return id;
    } catch (e) {
      if (!mounted) return null;
      setState(() => _error = errorText(e));
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPhoto() async {
    final id = _postId;
    if (id == null || _uploading) return;

    final source = await pickOne<ImageSource>(
      context,
      title: t('teacher.newsAddPhoto'),
      tint: Role.teacher.tint,
      options: [
        PickOption(
          value: ImageSource.camera,
          label: t('teacher.newsPhotoCamera'),
          icon: Icons.photo_camera_rounded,
        ),
        PickOption(
          value: ImageSource.gallery,
          label: t('teacher.newsPhotoGallery'),
          icon: Icons.photo_library_rounded,
        ),
      ],
    );
    if (source == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final shot = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 80);
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      final assetId = await TeacherApi.instance.uploadNewsPhoto(
        bytes: bytes,
        filename: 'news.jpg',
        mime: 'image/jpeg',
      );
      await TeacherApi.instance.attachNewsPhoto(id, assetId);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _nameChildren(TeacherNewsPhoto photo) async {
    final picked = await Navigator.of(context).push<_NamedChildren>(
      MaterialPageRoute(
        builder: (_) => _ChildPicker(
          children: _children,
          chosen: photo.taggedIds.toSet(),
          noChildren: photo.noChildren,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    try {
      await TeacherApi.instance.nameChildrenInNewsPhoto(
        photo.id,
        studentIds: picked.ids,
        noChildren: picked.noChildren,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final withheld = _children
          .where((c) => picked.ids.contains(c.id) && !c.photoConsent)
          .map((c) => c.name)
          .toList();
      if (withheld.isNotEmpty) {
        showNote(context, tv('teacher.newsConsentWarn', {'names': withheld.join('، ')}));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    }
  }

  Future<void> _removePhoto(TeacherNewsPhoto photo) async {
    try {
      await TeacherApi.instance.removeNewsPhoto(photo.id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    }
  }

  Future<void> _publish() async {
    final id = await _save();
    if (id == null || !mounted) return;

    final unnamed = _photos.where((p) => !p.named).length;
    if (unnamed > 0) {
      setState(() => _error = t('teacher.newsUnnamedStop'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final done = await TeacherApi.instance.publishNews(id);
      if (!mounted) return;
      showNote(context, tn('teacher.newsPublished', done.familiesTold));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _takeDown() async {
    final id = _postId;
    if (id == null) return;
    final sure = await confirmDialog(
      context,
      icon: Icons.delete_outline_rounded,
      title: t('teacher.newsRemove'),
      body: _published ? t('teacher.newsRemoveLiveWarn') : t('teacher.newsRemoveWarn'),
      confirmLabel: t('teacher.newsRemove'),
      confirmIcon: Icons.delete_outline_rounded,
    );
    if (!sure || !mounted) return;

    try {
      await TeacherApi.instance.takeDownNews(id);
      if (!mounted) return;
      showNote(context, t('teacher.newsRemoved'));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final id = _postId;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Heading(
              title: id == null ? t('teacher.newsWrite') : t('teacher.newsEdit'),
              subtitle: t('teacher.newsSubtitle'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: withBottomInset(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    _Label(t('teacher.newsClasses')),
                    Text(
                      t('teacher.newsClassesHint'),
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in widget.rights.classes)
                          FilterChip(
                            label: Text(c.name),
                            selected: _classIds.contains(c.id),
                            selectedColor: tint.withValues(alpha: 0.18),
                            onSelected: (on) => setState(
                              () => on ? _classIds.add(c.id) : _classIds.remove(c.id),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Label(t('teacher.newsText')),
                    TextField(
                      controller: _text,
                      maxLines: 5,
                      maxLength: widget.rights.textMax,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(hintText: t('teacher.newsTextHint')),
                    ),
                    const SizedBox(height: 8),
                    _Label(t('teacher.newsPhotos')),
                    if (id == null)
                      Text(
                        t('teacher.newsSaveFirst'),
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                      )
                    else ...[
                      if (_photos.isEmpty)
                        Text(
                          t('teacher.newsNoPhotos'),
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                        ),
                      for (final photo in _photos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PhotoRow(
                            photo: photo,
                            names: _children
                                .where((c) => photo.taggedIds.contains(c.id))
                                .map((c) => c.name)
                                .toList(),
                            onName: () => _nameChildren(photo),
                            onRemove: () => _removePhoto(photo),
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (_photos.length < widget.rights.photoLimit)
                        SoftButton(
                          label: _uploading ? t('teacher.newsUploading') : t('teacher.newsAddPhoto'),
                          icon: Icons.add_a_photo_outlined,
                          tint: tint,
                          onTap: _uploading ? null : _addPhoto,
                        )
                      else
                        Text(
                          tn('teacher.newsPhotoLimit', widget.rights.photoLimit),
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
                        ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.rose),
                      ),
                    ],
                    const SizedBox(height: 18),
                    BigButton(
                      label: t('teacher.newsSave'),
                      color: tint,
                      busy: _saving,
                      onPressed: _saving ? null : () => _save(),
                    ),
                    if (!_published) ...[
                      const SizedBox(height: 10),
                      SoftButton(
                        label: t('teacher.newsPublish'),
                        icon: Icons.send_rounded,
                        tint: tint,
                        height: 46,
                        onTap: _saving ? null : _publish,
                      ),
                    ],
                    if (id != null) ...[
                      const SizedBox(height: 10),
                      SoftButton(
                        label: t('teacher.newsRemove'),
                        icon: Icons.delete_outline_rounded,
                        tint: AppTheme.rose,
                        height: 46,
                        onTap: _takeDown,
                      ),
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

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photo,
    required this.names,
    required this.onName,
    required this.onRemove,
  });

  final TeacherNewsPhoto photo;
  final List<String> names;
  final VoidCallback onName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = photo.thumbnailUrl;

    return Card16(
      padding: const EdgeInsets.all(10),
      onTap: onName,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 54,
              height: 54,
              child: url == null
                  ? ColoredBox(
                      color: AppTheme.neutralSoft,
                      child: Icon(Icons.image_outlined, size: 20, color: AppTheme.textFaint),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: AppTheme.neutralSoft,
                        child: Icon(Icons.image_outlined, size: 20, color: AppTheme.textFaint),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.noChildren
                      ? t('teacher.newsNobody')
                      : names.isEmpty
                          ? t('teacher.newsUnnamed')
                          : names.join('، '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: photo.named ? AppTheme.text : AppTheme.amber,
                  ),
                ),
                if (photo.withheldForConsent) ...[
                  const SizedBox(height: 3),
                  Text(
                    t('teacher.newsWithheld'),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.amber),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.textFaint),
            tooltip: t('teacher.newsPhotoRemove'),
          ),
        ],
      ),
    );
  }
}

class _NamedChildren {
  const _NamedChildren({required this.ids, required this.noChildren});

  final List<String> ids;
  final bool noChildren;
}

class _ChildPicker extends StatefulWidget {
  const _ChildPicker({
    required this.children,
    required this.chosen,
    required this.noChildren,
  });

  final List<TeacherNewsChild> children;
  final Set<String> chosen;
  final bool noChildren;

  @override
  State<_ChildPicker> createState() => _ChildPickerState();
}

class _ChildPickerState extends State<_ChildPicker> {
  late final Set<String> _chosen = {...widget.chosen};
  late bool _noChildren = widget.noChildren;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tint = Role.teacher.tint;
    final needle = _query.trim().toLowerCase();
    final rows = needle.isEmpty
        ? widget.children
        : widget.children.where((c) => c.name.toLowerCase().contains(needle)).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Heading(
              title: t('teacher.newsWhoIsIn'),
              subtitle: t('teacher.newsWhoIsInHint'),
            ),
            Expanded(
              child: ListView(
                padding: withBottomInset(context, const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24)),
                children: [
                  SwitchListTile.adaptive(
                    value: _noChildren,
                    activeThumbColor: tint,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      t('teacher.newsNobody'),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                    ),
                    onChanged: (on) => setState(() {
                      _noChildren = on;
                      if (on) _chosen.clear();
                    }),
                  ),
                  if (!_noChildren) ...[
                    TextField(
                      decoration: InputDecoration(hintText: t('teacher.newsFindChild')),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 8),
                    if (rows.isEmpty)
                      Text(
                        t('teacher.newsNoChildren'),
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textFaint),
                      ),
                    for (final child in rows)
                      CheckboxListTile.adaptive(
                        value: _chosen.contains(child.id),
                        activeColor: tint,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          child.name,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                        ),
                        subtitle: child.photoConsent
                            ? null
                            : Text(
                                t('teacher.newsNoConsent'),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.amber),
                              ),
                        onChanged: (on) => setState(
                          () => on == true ? _chosen.add(child.id) : _chosen.remove(child.id),
                        ),
                      ),
                  ],
                  const SizedBox(height: 18),
                  BigButton(
                    label: t('teacher.newsDone'),
                    color: tint,
                    onPressed: () => Navigator.of(context).pop(
                      _NamedChildren(ids: _chosen.toList(), noChildren: _noChildren),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
      ),
    );
  }
}
