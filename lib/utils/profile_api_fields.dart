/// Normalizes user profile JSON from the API for admin/staff profile screens and saves.
class ProfileApiFields {
  ProfileApiFields._();

  static String? _first(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String departmentFrom(Map<String, dynamic> m) =>
      _first(m, const [
        'department',
        'departmentName',
        'dept',
        'team',
        'division',
      ]) ??
      '';

  static String designationFrom(Map<String, dynamic> m) =>
      _first(m, const [
        'designation',
        'jobTitle',
        'job_title',
        'title',
        'position',
        'roleTitle',
        'role_title',
      ]) ??
      '';

  static String phoneFrom(Map<String, dynamic> m) =>
      _first(m, const [
        'phoneNumber',
        'phone',
        'mobile',
        'mobileNumber',
      ]) ??
      '';

  static String managerFrom(Map<String, dynamic> m) =>
      _first(m, const [
        'managedBy',
        'manager',
        'reportsTo',
        'managerEmail',
      ]) ??
      '';

  /// Dropdown items: canonical [base] plus [raw] when it is not already represented.
  static List<String> dropdownOptionsFor(String raw, List<String> base) {
    final out = List<String>.from(base);
    final r = raw.trim();
    if (r.isEmpty) return out;
    if (!out.any((e) => e.toLowerCase() == r.toLowerCase())) {
      out.add(r);
    }
    return out;
  }

  /// Selected value for [DropdownButtonFormField] (must exist in [options]).
  static String? dropdownSelection(String raw, List<String> options) {
    final r = raw.trim();
    if (r.isEmpty) return null;
    for (final e in options) {
      if (e.toLowerCase() == r.toLowerCase()) return e;
    }
    return r;
  }
}
