import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/live_message_buffer.dart';
import 'package:simple_live_app/modules/live_room/live_status_refresh_policy.dart';
import 'package:simple_live_app/modules/live_room/playback_deadline.dart';

void main() {
  test('a high-traffic room keeps bounded, ordered batches', () {
    final buffer = LiveMessageBuffer<int>();
    for (var i = 0; i < 10000; i++) {
      buffer.add(i);
    }
    expect(buffer.length, 300);
    final batch = buffer.drain();
    expect(batch, List.generate(120, (i) => 9700 + i));
    expect(buffer.length, 180);
    buffer.clear();
    expect(buffer.drain(), isEmpty);
    buffer.add(10001);
    expect(buffer.drain(), [10001]);
  });

  test('sleep timer follows elapsed time after suspension', () {
    final timer = PlaybackDeadline();
    final start = DateTime(2026, 10, 7, 12);
    timer.start(const Duration(minutes: 30), start);
    expect(timer.remainingSeconds(start.add(const Duration(minutes: 29))), 60);
    expect(timer.isDue(start.add(const Duration(minutes: 31))), isTrue);
    expect(timer.remainingSeconds(start.add(const Duration(minutes: 31))), 0);
  });

  test('replacing or cancelling a timer removes the old deadline', () {
    final timer = PlaybackDeadline();
    final start = DateTime(2026, 10, 7, 12);
    timer.start(const Duration(minutes: 30), start);
    timer.start(const Duration(minutes: 90), start.add(const Duration(minutes: 20)));
    expect(timer.isDue(start.add(const Duration(minutes: 30))), isFalse);
    expect(timer.remainingSeconds(start.add(const Duration(minutes: 30))), 80 * 60);
    timer.stop();
    expect(timer.isDue(start.add(const Duration(days: 1))), isFalse);
  });

  test('active playback and transient offline responses cannot mark a room offline', () {
    final policy = LiveStatusRefreshPolicy();
    bool offline({bool live = false, bool playing = false}) =>
        policy.confirmOffline(reportedLive: live, hasActivePlaybackEvidence: playing);
    expect(offline(), isFalse);
    expect(offline(), isFalse);
    expect(offline(playing: true), isFalse);
    expect(policy.consecutiveOfflineCount, 0);
    expect(offline(), isFalse);
    expect(offline(live: true), isFalse);
    expect(offline(), isFalse);
    expect(offline(), isFalse);
    expect(offline(), isTrue);
    policy.reset();
    expect(policy.consecutiveOfflineCount, 0);
  });
}
