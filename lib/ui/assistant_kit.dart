import 'package:flutter/material.dart';

import '../api/parent_api.dart' show AiHistoryRow;
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'format.dart';
import 'kit.dart';

const int kAskLimit = 600;

String outcomeWord(String outcome) {
  const known = {
    'ANSWERED',
    'REFUSED_OFF_TOPIC',
    'REFUSED_OUT_OF_SCOPE',
    'BLOCKED_BY_LIMIT',
    'BLOCKED_PERSON',
    'PROVIDER_ERROR',
    'UNAVAILABLE',
  };
  return known.contains(outcome) ? t('aih.outcome.$outcome') : humanise(outcome);
}

String historyMeta(AiHistoryRow row, String kindLabel) {
  final parts = <String>[
    kindLabel,
    '${shortDate(row.at)} ${hhmm(row.at)}',
    outcomeWord(row.outcome),
    if (row.person != null) row.person!.label,
    if (row.schoolClass != null) row.schoolClass!.label,
  ];
  return parts.join(' · ');
}

class AssistantQuiet extends StatelessWidget {
  const AssistantQuiet({super.key, required this.icon, required this.text, this.note});

  final IconData icon;
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        children: [
          Icon(icon, size: 26, color: AppTheme.textFaint),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.textMuted),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.45, color: AppTheme.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class AssistantHistoryCard extends StatelessWidget {
  const AssistantHistoryCard({
    super.key,
    required this.row,
    required this.kindLabel,
    required this.icon,
    required this.open,
    required this.loading,
    required this.answer,
    required this.onTap,
  });

  final AiHistoryRow row;
  final String kindLabel;
  final IconData icon;
  final bool open;
  final bool loading;
  final String? answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final said = answer;

    return Card16(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppTheme.textFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    historyMeta(row, kindLabel),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, height: 1.4, color: AppTheme.textFaint),
                  ),
                ),
                Icon(
                  open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: AppTheme.textFaint,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              row.truncated ? '${row.question}…' : row.question,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: AppTheme.text,
              ),
            ),
            if (open) ...[
              const SizedBox(height: 10),
              if (loading)
                const AssistantWaitingLine()
              else
                Text(
                  said == null || said.isEmpty ? outcomeWord(row.outcome) : said,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: row.answered ? AppTheme.text : AppTheme.amber,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class AssistantFilterChoice {
  const AssistantFilterChoice({required this.value, required this.label});

  final String? value;
  final String label;
}

class AssistantFilterPills extends StatelessWidget {
  const AssistantFilterPills({
    super.key,
    required this.choices,
    required this.selected,
    required this.tint,
    required this.onChanged,
  });

  final List<AssistantFilterChoice> choices;
  final String? selected;
  final Color tint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final choice in choices) ...[
            _Pill(
              label: choice.label,
              chosen: choice.value == selected,
              tint: tint,
              onTap: () => onChanged(choice.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.chosen, required this.tint, required this.onTap});

  final String label;
  final bool chosen;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: chosen ? tint.withValues(alpha: 0.14) : AppTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: chosen ? tint : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
            color: chosen ? tint : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class AssistantWaitingLine extends StatelessWidget {
  const AssistantWaitingLine({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textFaint),
        ),
        const SizedBox(width: 10),
        Text(
          text ?? t('aih.loadingOlder'),
          style: TextStyle(fontSize: 11.5, color: AppTheme.textFaint),
        ),
      ],
    );
  }
}

class AssistantField extends StatelessWidget {
  const AssistantField({
    super.key,
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final edge = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppTheme.border),
    );

    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 2,
      maxLength: kAskLimit,
      enabled: enabled,
      style: TextStyle(fontSize: 14, color: AppTheme.text),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: AppTheme.canvas,
        border: edge,
        enabledBorder: edge,
      ),
      onChanged: onChanged,
    );
  }
}
