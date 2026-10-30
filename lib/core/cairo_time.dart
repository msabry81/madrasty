import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// كل أوقات الحصص تُخزَّن UTC وتُعرض وتُدخل بتوقيت القاهرة (يراعي التوقيت الصيفي).
class CairoTime {
  static late final tz.Location _loc;

  static void init() {
    tzdata.initializeTimeZones();
    _loc = tz.getLocation('Africa/Cairo');
  }

  static tz.TZDateTime toCairo(DateTime d) => tz.TZDateTime.from(d, _loc);

  /// يحوّل وقتًا مُدخلًا بتوقيت القاهرة إلى UTC للتخزين.
  static DateTime fromCairoWallClock(int y, int m, int d, int h, int min) {
    final ms = tz.TZDateTime(_loc, y, m, d, h, min).millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  static const _days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// الوقت فقط بتوقيت القاهرة (مثال: 04:30 م)
  static String formatTime(DateTime d) {
    final c = toCairo(d);
    final h = c.hour % 12 == 0 ? 12 : c.hour % 12;
    return '${_two(h)}:${_two(c.minute)} ${c.hour < 12 ? 'ص' : 'م'}';
  }

  static String format(DateTime d) {
    final c = toCairo(d);
    final h = c.hour % 12 == 0 ? 12 : c.hour % 12;
    return '${_days[c.weekday - 1]} ${c.year}-${_two(c.month)}-${_two(c.day)} — $h:${_two(c.minute)} ${c.hour < 12 ? 'ص' : 'م'}';
  }
}
