/// Prefix of ids of rows that are not saved yet (optimistic add).
const pendingIdPrefix = 'pending-';

bool isPendingId(String id) => id.startsWith(pendingIdPrefix);

String newPendingId() =>
    '$pendingIdPrefix${DateTime.now().microsecondsSinceEpoch}';

/// Runs writes one after another in call order, so quick taps never reach
/// the server out of order. A failed write does not block the next ones.
class WriteQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
