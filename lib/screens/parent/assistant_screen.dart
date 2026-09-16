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
import '../../ui/screen_kit.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.child});

  final Child child;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _text = TextEditingController();
  final _past = <AiHistoryRow>[];
  final _answers = <String, String?>{};

  int _tab = 0;
  bool _busy = false;
  AiChildAllowance? _left;

  late String? _only = widget.child.studentId;
  String? _cursor;
  bool _hasMore = false;
  bool _loadingPast = true;
  bool _loadingOlder = false;
  String? _pastFailed;
  String? _openId;
  String? _opening;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPast());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadPast() async {
    final round = ++_round;
    setState(() {
      _loadingPast = true;
      _pastFailed = null;
    });
    try {
      final page = await ParentApi.instance.aiHistory(studentId: _only);
      if (!mounted || round != _round) return;
      setState(() {
        _past
          ..clear()
          ..addAll(page.rows);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _loadingPast = false;
      });
    } on ApiException catch (e) {
      if (!mounted || round != _round) return;
      setState(() {
        _loadingPast = false;
        _pastFailed = e.message;
      });
    }
  }

  Future<void> _loadOlder() async {
    final cursor = _cursor;
    if (cursor == null || _loadingOlder || !_hasMore) return;
    final round = _round;
    setState(() => _loadingOlder = true);
    try {
      final page = await ParentApi.instance.aiHistory(studentId: _only, after: cursor);
      if (!mounted || round != _round) return;
      setState(() {
        final seen = _past.map((r) => r.id).toSet();
        _past.addAll(page.rows.where((r) => seen.add(r.id)));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
    if (mounted && round == _round) setState(() => _loadingOlder = false);
  }

  Future<void> _open(String id) async {
    if (_openId == id) {
      setState(() => _openId = null);
      return;
    }
    setState(() => _openId = id);
    if (_answers.containsKey(id)) return;
    setState(() => _opening = id);
    try {
      final entry = await ParentApi.instance.aiHistoryEntry(id);
      if (!mounted) return;
      setState(() => _answers[id] = entry.answer);
    } on ApiException catch (e) {
      if (!mounted) return;
      showNote(context, e.message, bad: true);
      setState(() => _openId = null);
    }
    if (mounted) setState(() => _opening = null);
  }

  void _filterBy(String? studentId) {
    if (_only == studentId) return;
    setState(() {
      _only = studentId;
      _openId = null;
    });
    _loadPast();
  }

  Future<void> _ask() async {
    final asked = _text.text.trim();
    if (asked.isEmpty || _busy) return;
    final forHomework = _tab == 0;
    setState(() => _busy = true);
    try {
      final answer = forHomework
          ? await ParentApi.instance.aiQuestion(studentId: widget.child.studentId, question: asked)
          : await ParentApi.instance.aiChildReport(studentId: widget.child.studentId, question: asked);
      if (!mounted) return;
      setState(() {
        _text.clear();
        final seen = _left;
        if (answer.remaining != null && seen != null) {
          _left = AiChildAllowance(
            studentId: seen.studentId,
            name: seen.name,
            limit: seen.limit,
            remaining: answer.remaining!,
            resetsOn: answer.resetsOn ?? seen.resetsOn,
          );
        }
      });
      await _loadPast();
      final newest = _past.isEmpty ? null : _past.first;
      if (newest != null && mounted) await _open(newest.id);
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  bool _nearEnd(ScrollNotification note) =>
      note.metrics.maxScrollExtent - note.metrics.pixels < 260;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('ai.title')),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (note) {
                  if (_nearEnd(note)) unawaited(_loadOlder());
                  return false;
                },
                child: Loader<AiOverview>(
                  tint: tint,
                  padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                  load: ParentApi.instance.aiOverview,
                  builder: (context, overview) {
                    if (!overview.available) {
                      return AssistantQuiet(icon: Icons.cloud_off_rounded, text: t('ai.unavailable'));
                    }

                    final allowance = _left ?? overview.forChild(widget.child.studentId);
                    _left ??= allowance;
                    final spent = allowance?.spent ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PillTabs(
                          tint: tint,
                          index: _tab,
                          onChanged: (i) => setState(() => _tab = i),
                          tabs: [
                            TabSpec(label: t('ai.tab.question'), icon: Icons.school_outlined),
                            TabSpec(label: t('ai.tab.report'), icon: Icons.insights_outlined),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _tab == 0 ? t('ai.questionLead') : t('ai.reportLead'),
                          style: TextStyle(fontSize: 12.5, height: 1.45, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Card16(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AssistantField(
                                controller: _text,
                                hint: _tab == 0 ? t('ai.questionHint') : t('ai.reportHint'),
                                enabled: !_busy && !spent,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      allowanceLine(allowance),
                                      style: TextStyle(fontSize: 11.5, height: 1.4, color: AppTheme.textFaint),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton(
                                    onPressed: _busy || spent || _text.text.trim().isEmpty ? null : _ask,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: tint,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                    ),
                                    child: Text(_busy ? t('ai.thinking') : t('ai.ask')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: kCardGap),
                        Text(
                          t('aih.past'),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t('aih.note'),
                          style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textFaint),
                        ),
                        if (overview.children.length > 1) ...[
                          const SizedBox(height: 10),
                          AssistantFilterPills(
                            tint: tint,
                            selected: _only,
                            onChanged: _filterBy,
                            choices: [
                              AssistantFilterChoice(value: null, label: t('aih.allChildren')),
                              for (final c in overview.children)
                                AssistantFilterChoice(value: c.studentId, label: c.name),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        ..._pastCards(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pastCards() {
    final failed = _pastFailed;
    if (failed != null) {
      return [AssistantQuiet(icon: Icons.wifi_off_rounded, text: t('aih.failed'), note: failed)];
    }
    if (_loadingPast) return [const AssistantWaitingLine()];
    if (_past.isEmpty) {
      return [
        AssistantQuiet(
          icon: Icons.auto_awesome_outlined,
          text: t('ai.nothingAsked'),
          note: t('ai.scopeNote'),
        ),
      ];
    }

    return [
      for (final row in _past) ...[
        AssistantHistoryCard(
          row: row,
          kindLabel: _kindLabel(row.kind),
          icon: _kindIcon(row.kind),
          open: _openId == row.id,
          loading: _opening == row.id,
          answer: _answers[row.id],
          onTap: () => _open(row.id),
        ),
        const SizedBox(height: kCardGap),
      ],
      if (_hasMore) const AssistantWaitingLine(),
    ];
  }

  static String _kindLabel(String kind) =>
      kind == 'CHILD_REPORT' ? t('ai.tab.report') : t('ai.tab.question');

  static IconData _kindIcon(String kind) =>
      kind == 'CHILD_REPORT' ? Icons.insights_outlined : Icons.school_outlined;
}

String allowanceLine(AiChildAllowance? allowance) {
  if (allowance == null) return '';
  if (allowance.remaining > 0) {
    return tv('ai.left', {'left': allowance.remaining, 'limit': allowance.limit});
  }
  final back = allowance.resetsOn;
  return back == null ? t('ai.spent') : tv('ai.spentUntil', {'when': back});
}
