import 'dart:collection';

/// Keep burst traffic bounded and publish one chat update per batch.
class LiveMessageBuffer<T> {
  LiveMessageBuffer({this.capacity = 300}) : assert(capacity > 0);

  final int capacity;
  final Queue<T> _items = Queue<T>();

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;

  void add(T item) {
    if (_items.length == capacity) _items.removeFirst();
    _items.addLast(item);
  }

  List<T> drain({int limit = 120}) {
    assert(limit > 0);
    final result = <T>[];
    while (_items.isNotEmpty && result.length < limit) {
      result.add(_items.removeFirst());
    }
    return result;
  }

  void clear() => _items.clear();
}
