import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/screens/parent/alert_routes.dart';

void main() {
  test('every transport alert a family received today opens that child\'s bus or live map', () {
    const expected = {
      'transport.bus_started': AlertDestination.track,
      'transport.bus_approaching': AlertDestination.track,
      'transport.bus_at_stop': AlertDestination.track,
      'transport.child_boarded': AlertDestination.track,
      'transport.child_arrived_school': AlertDestination.bus,
      'transport.child_dropped_off': AlertDestination.bus,
      'transport.child_not_boarded': AlertDestination.bus,
      'transport.child_unaccounted': AlertDestination.track,
    };
    expected.forEach((key, destination) {
      expect(alertDestinationFor(key, null), destination, reason: key);
    });
  });

  test('unknown keys fall back on their family, then their category, then the alerts list', () {
    expect(alertDestinationFor('transport.something_new', null), AlertDestination.bus);
    expect(alertDestinationFor('billing.refund_issued', null), AlertDestination.appFee);
    expect(alertDestinationFor(null, 'ATTENDANCE'), AlertDestination.attendance);
    expect(alertDestinationFor(null, 'SAFETY_CRITICAL'), AlertDestination.track);
    expect(alertDestinationFor('telemetry.device_silence', 'OPERATIONAL'), AlertDestination.alerts);
    expect(alertDestinationFor(null, null), AlertDestination.alerts);
  });

  test('a push tap reads the data the server attaches', () {
    final link = AlertLink.fromPush({
      'notificationId': 'n1',
      'templateKey': 'transport.child_boarded',
      'category': 'CUSTODY_EVENT',
      'studentId': 's1',
      'sourceType': 'CUSTODY_EVENT',
      'sourceId': 'c1',
    })!;
    expect(link.notificationId, 'n1');
    expect(link.studentId, 's1');
    expect(link.destination, AlertDestination.track);
    expect(link.threadId, isNull);
  });

  test('a news post opens the feed, not the alerts list', () {
    expect(alertDestinationFor('news.published', 'ANNOUNCEMENT'), AlertDestination.news);
    expect(alertDestinationFor('news.something_new', null), AlertDestination.news);
    expect(alertDestinationFor('announcement.broadcast', null), AlertDestination.announcement);
  });

  test('a push without our data is not routed', () {
    expect(AlertLink.fromPush(null), isNull);
    expect(AlertLink.fromPush({}), isNull);
    expect(AlertLink.fromPush({'studentId': 's1'}), isNull);
  });

  test('threads and announcements are found through the source', () {
    final reply = AlertLink.fromPush({
      'notificationId': 'n2',
      'templateKey': 'message.reply_from_school',
      'sourceType': 'MESSAGE_THREAD',
      'sourceId': 't1',
    })!;
    expect(reply.destination, AlertDestination.conversation);
    expect(reply.threadId, 't1');

    final notice = AlertLink.fromPush({
      'notificationId': 'n3',
      'templateKey': 'announcement.broadcast',
      'sourceType': 'ANNOUNCEMENT',
      'sourceId': 'a1',
    })!;
    expect(notice.destination, AlertDestination.announcement);
    expect(notice.announcement, 'a1');
  });
}
