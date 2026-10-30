import 'models.dart';

/// الدروس مرتّبة حسب ترتيب الوحدة ثم ترتيب الدرس.
List<Lesson> orderLessons(List<Unit> units, List<Lesson> lessons) {
  final rank = {for (var i = 0; i < units.length; i++) units[i].id: i};
  return [...lessons]..sort((a, b) {
      final c = (rank[a.unitId] ?? 9999).compareTo(rank[b.unitId] ?? 9999);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
}
