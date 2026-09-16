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
  final _turns = <AssistantTurn>[];

  int _tab = 0;
  bool _busy = false;
  AiChildAllowance? _left;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
        _turns.insert(
          0,
          AssistantTurn(
            question: asked,
            answer: answer.answer,
            ok: answer.ok,
            icon: forHomework ? Icons.school_outlined : Icons.insights_outlined,
          ),
        );
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
    } on ApiException catch (e) {
      if (mounted) showNote(context, e.message, bad: true);
    }
    if (mounted) setState(() => _busy = false);
  }

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
                      if (_turns.isEmpty)
                        AssistantQuiet(
                          icon: Icons.auto_awesome_outlined,
                          text: t('ai.nothingAsked'),
                          note: t('ai.scopeNote'),
                        )
                      else
                        for (final turn in _turns) ...[
                          AssistantTurnCard(turn: turn),
                          const SizedBox(height: kCardGap),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String allowanceLine(AiChildAllowance? allowance) {
  if (allowance == null) return '';
  if (allowance.remaining > 0) {
    return tv('ai.left', {'left': allowance.remaining, 'limit': allowance.limit});
  }
  final back = allowance.resetsOn;
  return back == null ? t('ai.spent') : tv('ai.spentUntil', {'when': back});
}
