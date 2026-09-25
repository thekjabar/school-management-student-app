import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../i18n/strings.dart';
import '../ui/format.dart';
import 'client.dart';
import 'parent_api.dart';

const String _role = String.fromEnvironment('APP_ROLE');

typedef BusLine = ({String id, String name, String line, bool live});

BusLine busWidgetLine(LiveBus bus) {
  final name = bus.studentName.trim().split(RegExp(r'\s+')).first;
  if (bus.alightedAt != null && !bus.onBoard) {
    return (id: bus.studentId, name: name, line: tv('widget.droppedAt', {'time': hhmm(bus.alightedAt)}), live: false);
  }
  if (bus.onBoard) return (id: bus.studentId, name: name, line: t('widget.onBus'), live: false);
  if (bus.visible && !bus.stale && bus.etaMinutes != null) {
    final eta = bus.etaMinutes!;
    if (eta <= 0) return (id: bus.studentId, name: name, line: t('widget.atPickup'), live: true);
    return (id: bus.studentId, name: name, line: tn('widget.arrivesIn', eta), live: true);
  }
  return (id: bus.studentId, name: name, line: bus.reasonText, live: false);
}

abstract final class BusWidget {
  static const provider = 'com.kurdistanstudentprotection.ksp.BusWidgetProvider';
  static const _task = 'ksp.busWidget.refresh';
  static const maxChildren = 3;
  static const _redrawEvery = Duration(minutes: 5);
  static const _redraws = 12;

  static bool get applies => _role == 'parent';

  static Future<void> start() async {
    if (!applies) return;
    try {
      await Workmanager().initialize(busWidgetDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('bus widget: could not schedule the refresh: $e');
    }
  }

  static Future<void> refresh() async {
    if (!applies) return;
    try {
      if (!ApiClient.instance.hasSession) {
        await _save(state: 'message', message: t('widget.signIn'), lines: const []);
        return;
      }
      await Entitlements.instance.refresh();
      final rights = Entitlements.instance.current.value;
      final buses = await ParentApi.instance.live();
      final open = [
        for (final b in buses)
          if (rights.access(b.studentId, ParentSection.track) == SectionAccess.open ||
              rights.access(b.studentId, ParentSection.track) == SectionAccess.unknown)
            b,
      ];
      if (buses.isNotEmpty && open.isEmpty) {
        await _save(state: 'message', message: t('widget.off'), lines: const []);
        return;
      }
      if (open.isEmpty) {
        await _save(state: 'message', message: t('widget.noChildren'), lines: const []);
        return;
      }
      await _save(
        state: 'ok',
        message: '',
        lines: [for (final b in open.take(maxChildren)) busWidgetLine(b)],
      );
    } catch (e) {
      debugPrint('bus widget: could not refresh: $e');
    }
  }

  static Future<void> signedOut() async {
    if (!applies) return;
    try {
      await _save(state: 'message', message: t('widget.signIn'), lines: const []);
    } catch (e) {
      debugPrint('bus widget: could not clear: $e');
    }
  }

  static Future<void> _save({
    required String state,
    required String message,
    required List<BusLine> lines,
  }) async {
    final now = DateTime.now();
    await HomeWidget.saveWidgetData<String>('ksp_state', state);
    await HomeWidget.saveWidgetData<String>('ksp_title', t('widget.title'));
    await HomeWidget.saveWidgetData<String>('ksp_message', message);
    await HomeWidget.saveWidgetData<String>('ksp_updated', tv('widget.updated', {'time': hhmm(now)}));
    await HomeWidget.saveWidgetData<String>('ksp_not_live', t('widget.notLive'));
    await HomeWidget.saveWidgetData<String>('ksp_updated_ms', '${now.millisecondsSinceEpoch}');
    await HomeWidget.saveWidgetData<String>('ksp_count', '${lines.length}');
    for (var i = 0; i < maxChildren; i++) {
      final line = i < lines.length ? lines[i] : null;
      await HomeWidget.saveWidgetData<String>('ksp_id_$i', line?.id ?? '');
      await HomeWidget.saveWidgetData<String>('ksp_name_$i', line?.name ?? '');
      await HomeWidget.saveWidgetData<String>('ksp_line_$i', line?.line ?? '');
      await HomeWidget.saveWidgetData<String>('ksp_live_$i', line?.live == true ? '1' : '0');
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: provider);
    await HomeWidget.scheduleWidgetUpdates(
      [for (var i = 1; i <= _redraws; i++) now.add(_redrawEvery * i)],
      qualifiedAndroidName: provider,
    );
  }
}

@pragma('vm:entry-point')
void busWidgetDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await AppLocale.restore();
      await ApiClient.instance.restore();
      await BusWidget.refresh();
    } catch (e) {
      debugPrint('bus widget: background refresh failed: $e');
    }
    return true;
  });
}
