import 'package:flutter/material.dart';

import '../../api/parent_api.dart';
import 'assignments_screen.dart';
import 'attendance_screen.dart';
import 'attitude_screen.dart';
import 'bus_screen.dart';
import 'conversation_screen.dart';
import 'dropoff_screen.dart';
import 'app_fee_screen.dart';
import 'marks_screen.dart';
import 'reports_screen.dart';
import 'school_fees_screen.dart';
import 'section_gate.dart';
import 'track_screen.dart';

enum AlertDestination {
  track,
  bus,
  dropoff,
  appFee,
  schoolFees,
  attendance,
  attitude,
  marks,
  assignments,
  reports,
  conversation,
  announcement,
  alerts,
}

const Map<String, AlertDestination> _byTemplate = {
  'transport.bus_started': AlertDestination.track,
  'transport.bus_approaching': AlertDestination.track,
  'transport.bus_at_stop': AlertDestination.track,
  'transport.child_boarded': AlertDestination.track,
  'transport.child_unaccounted': AlertDestination.track,
  'transport.child_wrong_bus': AlertDestination.track,
  'transport.child_wrong_stop': AlertDestination.track,
  'incident.declared': AlertDestination.track,
  'transport.child_not_boarded': AlertDestination.bus,
  'transport.child_arrived_school': AlertDestination.bus,
  'transport.child_dropped_off': AlertDestination.bus,
  'transport.child_home_confirmed': AlertDestination.bus,
  'transport.crew_changed': AlertDestination.bus,
  'transport.tomorrow_pickup': AlertDestination.bus,
  'route.rider.joining': AlertDestination.bus,
  'route.rider.leaving': AlertDestination.bus,
  'school.unscheduled_dismissal': AlertDestination.bus,
  'school.dismissal_cancelled': AlertDestination.bus,
  'transport.dropoff_changed': AlertDestination.dropoff,
  'transport.dropoff_change_refused': AlertDestination.dropoff,
  'billing.invoice_issued': AlertDestination.appFee,
  'billing.invoice_overdue': AlertDestination.appFee,
  'billing.payment_confirmed': AlertDestination.appFee,
  'package_payment.confirmed': AlertDestination.appFee,
  'package_payment.rejected': AlertDestination.appFee,
  'school_fees.payment.confirmed': AlertDestination.schoolFees,
  'school_fees.payment.rejected': AlertDestination.schoolFees,
  'academic.attendance_absent': AlertDestination.attendance,
  'academic.behaviour_recorded': AlertDestination.attitude,
  'academic.exam_result': AlertDestination.marks,
  'academic.homework_set': AlertDestination.assignments,
  'academic.report_card_ready': AlertDestination.reports,
  'message.reply_from_school': AlertDestination.conversation,
  'message.voice_from_school': AlertDestination.conversation,
  'announcement.broadcast': AlertDestination.announcement,
};

AlertDestination alertDestinationFor(String? templateKey, String? category) {
  final known = _byTemplate[templateKey];
  if (known != null) return known;
  final key = templateKey ?? '';
  if (key.startsWith('transport.')) return AlertDestination.bus;
  if (key.startsWith('school_fees.') || key.startsWith('school_fee.') || key.startsWith('schoolfee.')) {
    return AlertDestination.schoolFees;
  }
  if (key.startsWith('billing.') || key.startsWith('package_payment.') || key.startsWith('package.')) {
    return AlertDestination.appFee;
  }
  if (key.startsWith('message.')) return AlertDestination.conversation;
  if (key.startsWith('announcement.')) return AlertDestination.announcement;
  return switch (category) {
    'SAFETY_CRITICAL' || 'ARRIVAL_ETA' => AlertDestination.track,
    'TRIP_STATUS' || 'DELAY' || 'CUSTODY_EVENT' || 'NO_SHOW' => AlertDestination.bus,
    'BILLING' => AlertDestination.appFee,
    'ATTENDANCE' => AlertDestination.attendance,
    'MESSAGE' => AlertDestination.conversation,
    'ANNOUNCEMENT' => AlertDestination.announcement,
    _ => AlertDestination.alerts,
  };
}

class AlertLink {
  const AlertLink({
    this.notificationId,
    this.templateKey,
    this.category,
    this.studentId,
    this.sourceType,
    this.sourceId,
    this.announcementId,
  });

  final String? notificationId;
  final String? templateKey;
  final String? category;
  final String? studentId;
  final String? sourceType;
  final String? sourceId;
  final String? announcementId;

  factory AlertLink.fromAlert(ParentAlert alert) => AlertLink(
        notificationId: alert.id,
        templateKey: alert.templateKey,
        category: alert.category,
        studentId: alert.studentId,
        sourceType: alert.sourceType,
        sourceId: alert.sourceId,
        announcementId: alert.announcementId,
      );

  static AlertLink? fromPush(Map<String, dynamic>? data) {
    if (data == null) return null;
    String? read(String key) {
      final v = data[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final link = AlertLink(
      notificationId: read('notificationId'),
      templateKey: read('templateKey'),
      category: read('category'),
      studentId: read('studentId'),
      sourceType: read('sourceType'),
      sourceId: read('sourceId'),
    );
    if (link.notificationId == null && link.templateKey == null) return null;
    return link;
  }

  AlertDestination get destination => alertDestinationFor(templateKey, category);

  String? get threadId => sourceType == 'MESSAGE_THREAD' ? sourceId : null;

  String? get announcement => announcementId ?? (sourceType == 'ANNOUNCEMENT' ? sourceId : null);
}

enum MessagesFilter { all, alerts, announcements, notices, urgent, conversations }

class MessagesFocus {
  const MessagesFocus(this.filter, {this.announcementId});

  final MessagesFilter filter;
  final String? announcementId;
}

Future<void> openAlertDestination(
  BuildContext context, {
  required AlertLink link,
  required Child? child,
  required List<Child> household,
  required void Function(MessagesFocus focus) showInMessages,
}) async {
  final ids = [for (final c in household) c.studentId];

  Future<void> forChild(String section, Widget Function(Child c) screen) async {
    if (child == null) {
      showInMessages(const MessagesFocus(MessagesFilter.alerts));
      return;
    }
    await openSection<void>(
      context,
      childId: child.studentId,
      section: section,
      builder: (_) => screen(child),
    );
  }

  switch (link.destination) {
    case AlertDestination.track:
      await forChild(ParentSection.track, (c) => TrackScreen(child: c));
    case AlertDestination.bus:
      await forChild(ParentSection.bus, (c) => BusScreen(child: c));
    case AlertDestination.attendance:
      await forChild(ParentSection.attendance, (c) => AttendanceScreen(child: c));
    case AlertDestination.attitude:
      await forChild(ParentSection.attitude, (c) => AttitudeScreen(child: c));
    case AlertDestination.marks:
      await forChild(ParentSection.marks, (c) => MarksScreen(child: c));
    case AlertDestination.assignments:
      await forChild(ParentSection.assignments, (c) => AssignmentsScreen(child: c));
    case AlertDestination.reports:
      await forChild(ParentSection.reports, (c) => ReportsScreen(child: c));
    case AlertDestination.appFee:
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const AppFeeScreen()));
    case AlertDestination.schoolFees:
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const SchoolFeesScreen()));
    case AlertDestination.dropoff:
      await openHouseholdSection<void>(
        context,
        childIds: ids,
        section: ParentSection.dropoff,
        builder: (_) => const DropoffScreen(),
      );
    case AlertDestination.conversation:
      final thread = await _threadFor(link.threadId);
      if (thread == null || !context.mounted) {
        showInMessages(const MessagesFocus(MessagesFilter.conversations));
        return;
      }
      await openSection<void>(
        context,
        childId: thread.studentId,
        section: ParentSection.messages,
        builder: (_) => ConversationScreen(thread: thread),
      );
    case AlertDestination.announcement:
      showInMessages(MessagesFocus(MessagesFilter.announcements, announcementId: link.announcement));
    case AlertDestination.alerts:
      showInMessages(const MessagesFocus(MessagesFilter.alerts));
  }
}

Future<ThreadSummary?> _threadFor(String? id) async {
  if (id == null) return null;
  try {
    final threads = await ParentApi.instance.threads();
    for (final thread in threads) {
      if (thread.id == id) return thread;
    }
  } catch (_) {
  }
  return null;
}
