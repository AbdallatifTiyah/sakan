/// دوال تحقّق مشتركة لحقول النماذج — نفس نمط فحوصات القاعدة (طول رقم
/// الهاتف ٩-٢٠ محارف بعد trim، يطابق قيد contact_requests.seeker_phone)
/// بس هون عرض فوري بالواجهة قبل الإرسال، مش بديل عن تحقّق القاعدة.
String? requiredValidator(String? v, [String label = 'هذا الحقل']) {
  if (v == null || v.trim().isEmpty) return '$label مطلوب';
  return null;
}

String? phoneValidator(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'رقم الهاتف مطلوب';
  if (t.length < 9 || t.length > 20) return 'رقم الهاتف غير صحيح';
  if (!RegExp(r'^[0-9+\s-]+$').hasMatch(t)) return 'رقم الهاتف غير صحيح';
  return null;
}

String? numericValidator(String? v, {bool required = true, num? min, String label = 'القيمة'}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) {
    return required ? '$label مطلوب' : null;
  }
  final n = num.tryParse(t);
  if (n == null) return '$label يجب أن يكون رقماً';
  if (min != null && n < min) return '$label يجب أن يكون $min أو أكثر';
  return null;
}

String? integerValidator(String? v, {bool required = false, int? min, String label = 'القيمة'}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) {
    return required ? '$label مطلوب' : null;
  }
  final n = int.tryParse(t);
  if (n == null) return '$label يجب أن يكون رقماً صحيحاً';
  if (min != null && n < min) return '$label يجب أن يكون $min أو أكثر';
  return null;
}
