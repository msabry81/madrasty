/// يحوّل الأرقام العربية-الهندية (٠١٢...) إلى 0123 ثم يحلّلها.
String normalizeDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    b.write(i >= 0 ? i.toString() : ch);
  }
  return b.toString();
}

num? parseNum(String s) => num.tryParse(normalizeDigits(s.trim()));
