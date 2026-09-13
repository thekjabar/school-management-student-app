import 'package:flutter/material.dart';

import '../../api/crew_api.dart';
import '../../i18n/strings.dart';
import '../../theme/app_theme.dart';
import 'approach_prompts.dart';
import 'stop_announcer.dart';

class RunSnapshot {
  const RunSnapshot({
    required this.trip,
    required this.leg,
    required this.stops,
    required this.planStops,
    required this.school,
  });

  final CrewTrip? trip;
  final String leg;
  final List<PlannedStop> stops;
  final List<PlannedStop> planStops;
  final SchoolGate? school;

  bool get running => trip != null && trip!.startedAt != null && trip!.endedAt == null;

  bool get hasRiders => planStops.any((s) => s.students.isNotEmpty);

  PlannedStop? stopFor(String key) => stops.where((s) => runStopKey(s) == key).firstOrNull;
}

typedef RunStopPanel = Widget Function(BuildContext context, RunSnapshot run, PlannedStop stop);
typedef RunPanel = Widget? Function(BuildContext context, RunSnapshot run);

class RunDriving extends ChangeNotifier {
  RunDriving({
    required this.stopPanel,
    required this.schoolPanel,
    required this.runBar,
    required this.sos,
  });

  final RunStopPanel stopPanel;

  final RunPanel schoolPanel;

  final RunPanel runBar;

  final RunPanel sos;

  RunSnapshot? _run;

  RunSnapshot? get run => _run;

  void publish(RunSnapshot run) {
    _run = run;
    notifyListeners();
  }
}

class RunMapSheet extends StatelessWidget {
  const RunMapSheet({
    super.key,
    required this.driving,
    required this.selection,
    required this.onClose,
    this.maxHeightFraction = 0.55,
  });

  final RunDriving driving;

  final String? selection;

  final VoidCallback onClose;

  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: driving,
      builder: (context, _) {
        final run = driving.run;
        if (run == null) return const SizedBox.shrink();
        final selected = selection;
        final stop = selected == null || selected == kSchoolTargetKey ? null : run.stopFor(selected);
        final Widget? panel = selected == kSchoolTargetKey
            ? driving.schoolPanel(context, run)
            : stop != null
                ? driving.stopPanel(context, run, stop)
                : null;
        final bar = driving.runBar(context, run);
        if (panel == null && bar == null) return const SizedBox.shrink();

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.canvas.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: AppTheme.dark ? 0.45 : 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: panel == null
                              ? const SizedBox(height: 12)
                              : IconButton(
                                  tooltip: t('common.close'),
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.close_rounded, color: AppTheme.textMuted),
                                  onPressed: onClose,
                                ),
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: panel ??
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              bar!,
                              const SizedBox(height: 6),
                              Text(
                                t('driver.map.tapStopHint'),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class VoiceBanner extends StatelessWidget {
  const VoiceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StopAnnouncer.instance.banner,
      builder: (context, text, _) {
        if (text == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppTheme.blue,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.record_voice_over_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class VoiceToggle extends StatelessWidget {
  const VoiceToggle({super.key, required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: StopAnnouncer.instance.muted,
      builder: (context, muted, _) => Semantics(
        button: true,
        toggled: !muted,
        label: t(muted ? 'driver.map.voiceOff' : 'driver.map.voiceOn'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: StopAnnouncer.instance.toggleMute,
          child: MapRoundButton(
            icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            colour: muted ? AppTheme.textMuted : tint,
          ),
        ),
      ),
    );
  }
}

class MapRoundButton extends StatelessWidget {
  const MapRoundButton({super.key, required this.icon, required this.colour, this.turns = 0});

  final IconData icon;
  final Color colour;
  final double turns;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.dark ? 0.4 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Transform.rotate(
        angle: turns,
        child: Icon(icon, size: 21, color: colour),
      ),
    );
  }
}
