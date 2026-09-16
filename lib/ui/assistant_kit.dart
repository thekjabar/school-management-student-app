import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kit.dart';

const int kAskLimit = 600;

class AssistantTurn {
  const AssistantTurn({
    required this.question,
    required this.answer,
    required this.ok,
    required this.icon,
  });

  final String question;
  final String answer;
  final bool ok;
  final IconData icon;
}

class AssistantTurnCard extends StatelessWidget {
  const AssistantTurnCard({super.key, required this.turn});

  final AssistantTurn turn;

  @override
  Widget build(BuildContext context) {
    return Card16(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(turn.icon, size: 15, color: AppTheme.textFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  turn.question,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            turn.answer,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: turn.ok ? AppTheme.text : AppTheme.amber,
            ),
          ),
        ],
      ),
    );
  }
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
