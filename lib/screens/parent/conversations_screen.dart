import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/assistant_kit.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/pickers.dart';
import '../../ui/sheets.dart';
import '../../ui/screen_kit.dart';
import 'conversation_screen.dart';
import 'section_gate.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Heading(),
            const Expanded(child: _ConversationList()),
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
                  t('conv.screenTitle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.15,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t('conv.screenSubtitle'),
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
          Image.asset('assets/art/school_shield.png', width: 96),
        ],
      ),
    );
  }
}

class _ConversationList extends StatefulWidget {
  const _ConversationList();

  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> with FollowsReload<_ConversationList> {
  final _search = TextEditingController();
  final _rows = <ThreadSummary>[];

  Timer? _typing;
  int _request = 0;
  String _term = '';
  String? _childId;
  String? _status;
  List<Child> _children = const [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;
  bool _older = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadChildren();
    _load();
  }

  @override
  void dispose() {
    _typing?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void refetch() => _load();

  Future<void> _loadChildren() async {
    try {
      final all = await ParentApi.instance.children();
      await Entitlements.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _children = [
          for (final c in all)
            if (!sectionLocked(c.studentId, ParentSection.messages)) c,
        ];
      });
    } catch (_) {
    }
  }

  Future<void> _load({bool older = false}) async {
    final mine = ++_request;
    setState(() {
      if (older) {
        _older = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await ParentApi.instance.threadPage(
        status: _status,
        studentId: _childId,
        search: _term,
        page: older ? _page + 1 : 1,
      );
      if (!mounted || mine != _request) return;
      setState(() {
        if (!older) _rows.clear();
        _rows.addAll(page.rows);
        _page = page.page;
        _pages = page.pages;
        _loading = false;
        _older = false;
      });
    } catch (e) {
      if (!mounted || mine != _request) return;
      setState(() {
        _loading = false;
        _older = false;
        if (!older) _error = e;
      });
    }
  }

  void _typed(String value) {
    _typing?.cancel();
    _typing = Timer(const Duration(milliseconds: 350), () {
      final term = value.trim();
      final asked = term.length >= kThreadSearchMin ? term : '';
      if (asked == _term) return;
      _term = asked;
      _load();
    });
  }

  void _choose(void Function() change) {
    setState(change);
    _load();
  }

  bool _onScroll(ScrollNotification note) {
    if (_loading || _older || _page >= _pages) return false;
    final m = note.metrics;
    if (m.pixels >= m.maxScrollExtent - 240) _load(older: true);
    return false;
  }

  List<ThreadSummary> get _visible => [
        for (final thread in _rows)
          if (!sectionLocked(thread.studentId, ParentSection.messages)) thread,
      ];

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 24),
        children: [
          Card16(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
            child: Column(
              children: [
                SectionRow(
                  title: t('conv.title'),
                  actionLabel: t('conv.start'),
                  actionIcon: Icons.add_rounded,
                  onAction: () async {
                    await _startConversation(context);
                    if (mounted) _load();
                  },
                ),
                _SearchField(controller: _search, onChanged: _typed),
                const SizedBox(height: 10),
                if (_children.length > 1) ...[
                  AssistantFilterPills(
                    choices: [
                      AssistantFilterChoice(value: null, label: t('conv.allChildren')),
                      for (final c in _children)
                        AssistantFilterChoice(value: c.studentId, label: c.name),
                    ],
                    selected: _childId,
                    tint: tint,
                    onChanged: (v) => _choose(() => _childId = v),
                  ),
                  const SizedBox(height: 8),
                ],
                AssistantFilterPills(
                  choices: [
                    AssistantFilterChoice(value: null, label: t('conv.allStatus')),
                    AssistantFilterChoice(value: 'OPEN', label: t('conv.open')),
                    AssistantFilterChoice(value: 'RESOLVED', label: t('conv.resolved')),
                  ],
                  selected: _status,
                  tint: tint,
                  onChanged: (v) => _choose(() => _status = v),
                ),
                const SizedBox(height: 6),
                ..._body(tint),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(Color tint) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 22),
          child: Column(
            children: [
              Text(
                t('conv.failed'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: _load, child: Text(t('common.tryAgain'))),
            ],
          ),
        ),
      ];
    }
    final rows = _visible;
    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: Text(
              _term.isEmpty ? t('conv.none') : t('conv.noMatch'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) Divider(height: 1, color: AppTheme.border),
        _ThreadRow(
          thread: rows[i],
          tint: tint,
          onTap: () async {
            await openSection<void>(
              context,
              childId: rows[i].studentId,
              section: ParentSection.messages,
              builder: (_) => ConversationScreen(thread: rows[i]),
            );
            if (mounted) _load();
          },
        ),
      ],
      if (_older)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              t('conv.loadingOlder'),
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
        ),
    ];
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: 120,
      textInputAction: TextInputAction.search,
      style: TextStyle(fontSize: 13.5, color: AppTheme.text),
      decoration: InputDecoration(
        hintText: t('conv.search'),
        counterText: '',
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppTheme.textMuted),
        filled: true,
        fillColor: AppTheme.canvas,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({required this.thread, required this.tint, required this.onTap});

  final ThreadSummary thread;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: thread.unread ? FontWeight.w800 : FontWeight.w600,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    thread.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (thread.resolved)
              StatusChip(t('conv.resolved'), color: AppTheme.textMuted)
            else if (thread.unread)
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _startConversation(BuildContext context) async {
  final all = await ParentApi.instance.children();
  if (!context.mounted) return;
  if (all.isEmpty) {
    showNote(context, t('conv.none'), bad: true);
    return;
  }
  await Entitlements.instance.ensureLoaded();
  if (!context.mounted) return;
  final children = [
    for (final c in all)
      if (!sectionLocked(c.studentId, ParentSection.messages)) c,
  ];
  if (children.isEmpty) {
    await showSectionLocked(context, ParentSection.messages);
    return;
  }
  final opened = await showAppSheet<ThreadSummary>(
    context,
    builder: (_) => _NewConversationSheet(children: children),
  );
  if (opened == null || !context.mounted) return;
  await openSection<void>(
    context,
    childId: opened.studentId,
    section: ParentSection.messages,
    builder: (_) => ConversationScreen(thread: opened),
  );
}

const _topics = <String>[
  'GENERAL',
  'ABSENCE',
  'TRANSPORT',
  'ACADEMIC',
  'BEHAVIOUR',
  'HEALTH',
  'BILLING',
];

class _NewConversationSheet extends StatefulWidget {
  const _NewConversationSheet({required this.children});

  final List<Child> children;

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  late Child _child = widget.children.first;
  String _topic = 'GENERAL';
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickChild() async {
    final picked = await pickOne<String>(
      context,
      tint: Role.parent.tint,
      selected: _child.studentId,
      title: t('conv.whichChild'),
      options: [
        for (final c in widget.children)
          PickOption(value: c.studentId, label: c.name),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _child = widget.children.firstWhere((c) => c.studentId == picked));
  }

  Future<void> _pickTopic() async {
    final picked = await pickOne<String>(
      context,
      tint: Role.parent.tint,
      selected: _topic,
      title: t('conv.topic'),
      options: [
        for (final k in _topics) PickOption(value: k, label: t('conv.topic.$k')),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _topic = picked);
  }

  Future<void> _open() async {
    final subject = _subject.text.trim();
    final body = _body.text.trim();
    if (subject.length < 2 || body.isEmpty) {
      showNote(context, t('conv.needBoth'), bad: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ParentApi.instance.openThread(
        studentId: _child.studentId,
        subject: subject,
        body: body,
        topic: _topic,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ThreadSummary(
          id: id,
          subject: subject,
          topic: _topic,
          status: 'OPEN',
          studentId: _child.studentId,
          studentName: _child.name,
          lastMessageAt: DateTime.now(),
          lastMessageBy: 'FAMILY',
          messageCount: 1,
          unread: false,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showNote(context, e.message, bad: true);
      }
    }
  }

  InputDecoration _box(String hint) => InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: AppTheme.canvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                t('conv.start'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.children.length > 1) ...[
                PickerField(
                  label: t('conv.whichChild'),
                  value: _child.name,
                  onTap: _pickChild,
                ),
                const SizedBox(height: 14),
              ],
              PickerField(
                label: t('conv.topic'),
                value: t('conv.topic.$_topic'),
                onTap: _pickTopic,
              ),
              const SizedBox(height: 14),
              _label(t('conv.subject')),
              TextField(
                controller: _subject,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: _box(t('conv.subjectHint')),
              ),
              const SizedBox(height: 14),
              _label(t('conv.message')),
              TextField(
                controller: _body,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 14, color: AppTheme.text),
                decoration: _box(t('conv.writeSomething')),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: BigButton(
                  label: _busy ? t('conv.sending') : t('conv.send'),
                  color: tint,
                  onPressed: _busy ? null : _open,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
