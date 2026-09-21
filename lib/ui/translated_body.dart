import 'package:flutter/material.dart';

import '../i18n/strings.dart';
import '../theme/app_theme.dart';

class TranslatedBody extends StatefulWidget {
  const TranslatedBody({
    super.key,
    required this.body,
    required this.translated,
    required this.tint,
  });

  final String body;
  final String? translated;
  final Color tint;

  @override
  State<TranslatedBody> createState() => _TranslatedBodyState();
}

class _TranslatedBodyState extends State<TranslatedBody> {
  bool _original = false;

  @override
  Widget build(BuildContext context) {
    final translated = widget.translated;
    final style = TextStyle(fontSize: 13.5, color: AppTheme.text);

    if (translated == null || translated.isEmpty || translated == widget.body) {
      return Text(widget.body, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_original ? widget.body : translated, style: style),
        GestureDetector(
          onTap: () => setState(() => _original = !_original),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 1),
            child: Text(
              _original ? t('conv.showTranslation') : t('conv.translated'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.tint),
            ),
          ),
        ),
      ],
    );
  }
}
