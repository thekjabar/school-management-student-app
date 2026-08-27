import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<Student> _future = repository.student();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: FutureBuilder<Student>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppTheme.gutter),
              child: ErrorPanel(
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = repository.student()),
              ),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppTheme.gutter),
              child: LoadingSkeleton(height: 90, count: 4),
            );
          }

          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppTheme.gutter, 4, AppTheme.gutter, 28),
            children: [
              Panel(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s.initials,
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontSize: 16)),
                          const SizedBox(height: 3),
                          Text('${s.className} • ${s.code}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SectionLabel('Preferences'),
              const _Item(icon: Icons.translate_rounded, label: 'Language', value: 'کوردی'),
              const _Item(icon: Icons.notifications_none_rounded, label: 'Notifications', value: 'On'),
              const _Item(icon: Icons.dark_mode_outlined, label: 'Appearance', value: 'Light'),

              const SectionLabel('Privacy'),
              // Stated plainly rather than buried in a policy. A student is
              // entitled to know that the school can see where their bus is and
              // that nobody can see where they are.
              Panel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 17, color: AppTheme.textSecondary),
                        const SizedBox(width: 10),
                        Text('What this app can see',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _Bullet('Your timetable, marks and attendance, once the school publishes them.'),
                    const _Bullet('The position of your bus while it is on your route — not your own position.'),
                    const _Bullet('This app never tracks your phone, and never asks for its location.'),
                  ],
                ),
              ),

              const SectionLabel('Help'),
              const _Item(icon: Icons.help_outline_rounded, label: 'Contact the office', value: ''),
              const _Item(icon: Icons.info_outline_rounded, label: 'About', value: 'v1.0.0'),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      side: const BorderSide(color: AppTheme.border, width: 0.8),
                    ),
                  ),
                  child: const Text('Sign out',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        onTap: () {},
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 13),
            Expanded(
              child: Text(label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
            ),
            if (value.isNotEmpty)
              Text(value, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 9),
            child: SizedBox(
              width: 3, height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppTheme.textMuted, shape: BoxShape.circle),
              ),
            ),
          ),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
          ),
        ],
      ),
    );
  }
}
