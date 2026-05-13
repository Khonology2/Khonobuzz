/// Human-readable label from an email local-part, e.g.
/// `nkosinathi.radebe@khonology.com` → `Nkosinathi Radebe`.
String userDisplayNameFromEmail(String? email) {
  if (email == null || email.trim().isEmpty) return '';
  final local = email.split('@').first.trim();
  if (local.isEmpty) return '';
  final parts = local.split(RegExp(r'[.\-_]'));
  return parts
      .where((s) => s.isNotEmpty)
      .map(
        (s) => s.length > 1
            ? '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}'
            : s.toUpperCase(),
      )
      .join(' ');
}
