import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import '../../ui/async.dart';
import '../../ui/home_kit.dart';
import '../../ui/kit.dart';
import '../../ui/screen_kit.dart';
import 'consent_form_screen.dart';

class ConsentsScreen extends StatelessWidget {
  const ConsentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: t('consent.title'), subtitle: t('consent.subtitle')),
            Expanded(
              child: Loader<ConsentBook>(
                tint: tint,
                padding: const EdgeInsets.fromLTRB(kGutter, 4, kGutter, 28),
                load: () => ParentApi.instance.consents(),
                empty: t('common.noChildren'),
                isEmpty: (book) => book.children.isEmpty,
                builder: (context, book) => _Book(book: book),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Book extends StatelessWidget {
  const _Book({required this.book});

  final ConsentBook book;

  @override
  Widget build(BuildContext context) {
    final anyForms = book.children.any((child) => child.forms.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!anyForms)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Column(
              children: [
                Icon(Icons.task_alt_rounded, size: 34, color: AppTheme.textFaint),
                const SizedBox(height: 12),
                Text(
                  t('consent.noneAsked'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          )
        else if (book.awaitingCount > 0)
          NoticeBanner(
            icon: Icons.assignment_late_outlined,
            color: AppTheme.amber,
            title: tn('consent.awaitingCount', book.awaitingCount),
            body: t('consent.readFully'),
          )
        else
          NoticeBanner(
            icon: Icons.verified_rounded,
            color: AppTheme.green,
            title: t('consent.allAnswered'),
            body: t('consent.subtitle'),
          ),
        if (anyForms) const SizedBox(height: kCardGap),
        for (final child in book.children) ...[
          _Child(child: child),
          const SizedBox(height: kCardGap),
        ],
      ],
    );
  }
}

class _Child extends StatelessWidget {
  const _Child({required this.child});

  final ChildConsents child;

  @override
  Widget build(BuildContext context) {
    final tint = Role.parent.tint;
    final firstName = child.name.split(' ').first;

    return Card16(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleInitials(label: child.name, tint: tint, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      child.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (child.awaitingCount > 0)
                Pill(tn('consent.waitingHere', child.awaitingCount), color: AppTheme.amber),
            ],
          ),
          const SizedBox(height: 4),
          if (child.forms.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Text(
                tn('consent.noneAskedFor', firstName),
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
              ),
            )
          else
            for (final form in child.forms) ...[
              Divider(height: 1, color: AppTheme.border),
              _FormRow(child: child, form: form),
            ],
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.child, required this.form});

  final ChildConsents child;
  final ConsentForm form;

  @override
  Widget build(BuildContext context) {
    final look = consentStatusLook(form.status);
    final answered = consentAnsweredLine(form);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConsentFormScreen(
            studentId: child.studentId,
            childName: child.name,
            policyVersionId: form.policyVersionId,
          ),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consentPurposeLabel(form.purpose),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      height: 1.3,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    answered ?? tn('consent.version', form.version),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(look.label, color: look.colour),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppTheme.textFaint),
          ],
        ),
      ),
    );
  }
}
