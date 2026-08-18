/// Runs `action` over `items` with at most `concurrency` operations in flight at once.
Future<void> forEachBounded<T>(
  List<T> items,
  int concurrency,
  Future<void> Function(T item) action,
) async {
  var index = 0;

  Future<void> worker() async {
    while (true) {
      final current = index;
      if (current >= items.length) return;
      index++;
      await action(items[current]);
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
}
