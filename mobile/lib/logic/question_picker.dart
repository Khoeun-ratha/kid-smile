import 'dart:math';

/// Picks which questions a quiz uses, in play order.
///
/// - Random every time.
/// - Spreads picks across categories round-robin, so a mixed quiz isn't
///   swamped by whichever category has the most questions (e.g. the
///   hundreds of generated arithmetic questions).
/// - Prefers questions not in [recent] (oldest first); when a pool is too
///   small to avoid them all, the least recently played ones are reused
///   first.
List<int> pickQuestionIds({
  required List<({int id, int categoryId})> pool,
  required int count,
  List<int> recent = const [],
  Random? random,
}) {
  final rng = random ?? Random();
  final recentRank = {for (var i = 0; i < recent.length; i++) recent[i]: i};
  final fresh = pool.where((q) => !recentRank.containsKey(q.id)).toList();

  final picked = _roundRobin(fresh, count, rng);
  if (picked.length < count) {
    final stale = pool.where((q) => recentRank.containsKey(q.id)).toList()
      ..sort((a, b) => recentRank[a.id]!.compareTo(recentRank[b.id]!));
    picked.addAll(stale.take(count - picked.length).map((q) => q.id));
  }
  return picked..shuffle(rng);
}

List<int> _roundRobin(
  List<({int id, int categoryId})> pool,
  int count,
  Random rng,
) {
  final byCategory = <int, List<int>>{};
  for (final q in pool) {
    byCategory.putIfAbsent(q.categoryId, () => []).add(q.id);
  }
  final queues = byCategory.values.map((ids) => ids..shuffle(rng)).toList()
    ..shuffle(rng);

  final picked = <int>[];
  var round = 0;
  while (picked.length < count && queues.any((q) => q.length > round)) {
    for (final queue in queues) {
      if (picked.length == count) break;
      if (queue.length > round) picked.add(queue[round]);
    }
    round++;
  }
  return picked;
}
