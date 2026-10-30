class Validators {
  static String? required(String? v, [String msg = 'هذا الحقل مطلوب']) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  static String? email(String? v) {
    final r = required(v);
    if (r != null) return r;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!.trim());
    return ok ? null : 'بريد إلكتروني غير صالح';
  }

  static String? password(String? v) {
    final r = required(v);
    if (r != null) return r;
    return v!.length < 8 ? 'كلمة المرور 8 أحرف على الأقل' : null;
  }

  static String? phoneOptional(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^01[0125][0-9]{8}$').hasMatch(v.trim())
        ? null
        : 'رقم هاتف مصري غير صالح';
  }
}
