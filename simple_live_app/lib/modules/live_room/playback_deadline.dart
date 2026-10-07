/// A wall-clock deadline stays accurate after the OS suspends timer callbacks.
class PlaybackDeadline {
  DateTime? deadline;

  void start(Duration duration, DateTime now) {
    assert(duration > Duration.zero);
    deadline = now.add(duration);
  }

  int remainingSeconds(DateTime now) {
    final milliseconds = deadline?.difference(now).inMilliseconds ?? 0;
    return milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
  }

  bool isDue(DateTime now) => deadline != null && !now.isBefore(deadline!);

  void stop() => deadline = null;
}
