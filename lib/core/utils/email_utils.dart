/// Email helpers for Google sign-in identities and invites.
library;

/// Trims and lowercases an email address (invite ids and `users.email`).
String normalizeEmail(String email) => email.trim().toLowerCase();

final _emailPattern = RegExp(r'^[a-z0-9._%+\-]+@[a-z0-9\-]+(\.[a-z0-9\-]+)*\.[a-z]{2,}$');

/// The lowercased email, or null if [input] is not a plausible address.
String? validEmailOrNull(String? input) {
  if (input == null) return null;
  final email = normalizeEmail(input);
  if (email.length > 254 || !_emailPattern.hasMatch(email)) return null;
  return email;
}
