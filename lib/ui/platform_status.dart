import 'package:flutter/material.dart';

import '../api/status.dart';
import '../i18n/strings.dart';
import '../theme/app_theme.dart';
import 'format.dart';

class StatusGate extends StatefulWidget {
  const StatusGate({super.key, required this.child, this.role = Role.parent});

  final Widget child;

  final Role role;

  @override
  State<StatusGate> createState() => _StatusGateState();
}

class _StatusGateState extends State<StatusGate> with WidgetsBindingObserver {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PlatformStatusService.instance.refresh();
    }
  }

  @override
  Future<bool> didPopRoute() async {
    final answer = PlatformStatusService.instance.current.value;
    if (answer.blocks) return true;
    if (_showing(answer)) {
      await _dismiss(answer);
      return true;
    }
    return false;
  }

  bool _showing(PlatformStatus answer) =>
      answer.state == PlatformState.notice && !PlatformStatusService.instance.suppressed;

  Future<void> _dismiss(PlatformStatus answer) async {
    final id = answer.id;
    if (id != null) await PlatformStatusService.instance.dismiss(id);
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await PlatformStatusService.instance.refresh();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlatformStatus>(
      valueListenable: PlatformStatusService.instance.current,
      builder: (context, answer, _) {
        if (answer.blocks) {
          return MaintenanceScreen(
            answer: answer,
            role: widget.role,
            refreshing: _refreshing,
            onRefresh: _refresh,
          );
        }

        return Stack(
          children: [
            widget.child,
            if (_showing(answer))
              StatusNotice(
                answer: answer,
                role: widget.role,
                onClose: () => _dismiss(answer),
              ),
          ],
        );
      },
    );
  }
}

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({
    super.key,
    required this.answer,
    required this.onRefresh,
    this.role = Role.parent,
    this.refreshing = false,
  });

  final PlatformStatus answer;

  final Future<void> Function() onRefresh;

  final Role role;

  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final driver = role == Role.driver;
    final tint = role.tint;

    return Material(
      color: AppTheme.canvas,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: driver ? 116 : 96,
                  height: driver ? 116 : 96,
                  decoration: BoxDecoration(color: role.wash, shape: BoxShape.circle),
                  child: Icon(
                    Icons.construction_rounded,
                    size: driver ? 54 : 44,
                    color: tint,
                  ),
                ),
                SizedBox(height: driver ? 28 : 24),
                Text(
                  answer.title ?? t('status.maintenanceTitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: driver ? 26 : 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  answer.message ?? t('status.maintenanceBody'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: driver ? 18 : 15,
                    height: 1.6,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (answer.endsAt != null) ...[
                  SizedBox(height: driver ? 24 : 20),
                  _EndsAt(at: answer.endsAt!, tint: tint, driver: driver),
                ],
                SizedBox(height: driver ? 32 : 28),
                _StatusButton(
                  label: t('status.refresh'),
                  icon: Icons.refresh_rounded,
                  tint: tint,
                  busy: refreshing,
                  driver: driver,
                  onTap: onRefresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusNotice extends StatelessWidget {
  const StatusNotice({
    super.key,
    required this.answer,
    required this.onClose,
    this.role = Role.parent,
  });

  final PlatformStatus answer;

  final VoidCallback onClose;

  final Role role;

  @override
  Widget build(BuildContext context) {
    final driver = role == Role.driver;

    return Stack(
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: AppTheme.dark ? 0.62 : 0.34),
          dismissible: true,
          onDismiss: onClose,
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
            child: Material(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(color: role.wash, shape: BoxShape.circle),
                      child: Icon(Icons.campaign_rounded, size: 36, color: role.tint),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      answer.title ?? t('status.noticeTitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: driver ? 22 : 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      answer.message ?? t('status.noticeBody'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: driver ? 16 : 14.5,
                        height: 1.55,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (answer.startsAt != null || answer.endsAt != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        statusWindowCaption(answer.startsAt, answer.endsAt),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: driver ? 15 : 13.5,
                          fontWeight: FontWeight.w700,
                          color: role.tint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _StatusButton(
                      label: t('common.close'),
                      icon: Icons.close_rounded,
                      tint: role.tint,
                      driver: driver,
                      onTap: () async => onClose(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EndsAt extends StatelessWidget {
  const _EndsAt({required this.at, required this.tint, required this.driver});

  final DateTime at;
  final Color tint;
  final bool driver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.neutralSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        tn('status.backBy', statusMoment(at)),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: driver ? 17 : 14,
          fontWeight: FontWeight.w700,
          color: tint,
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.tint,
    required this.onTap,
    required this.driver,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Future<void> Function() onTap;
  final bool driver;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: busy ? null : () => onTap(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: driver ? 34 : 28, vertical: driver ? 18 : 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: driver ? 22 : 18,
                  height: driver ? 22 : 18,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(icon, size: driver ? 22 : 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: driver ? 18 : 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String statusMoment(DateTime at) {
  final now = DateTime.now();
  final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
  return sameDay ? hhmm(at) : '${shortDate(at)} ${hhmm(at)}';
}

String statusWindowCaption(DateTime? from, DateTime? to) {
  if (from != null && to != null) {
    return '${statusMoment(from)} – ${statusMoment(to)}';
  }
  if (to != null) return tn('status.backBy', statusMoment(to));
  if (from != null) return tn('status.startsAt', statusMoment(from));
  return '';
}
