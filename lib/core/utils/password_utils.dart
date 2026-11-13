/// Password and one-time-code rules for email sign-in (mirrors the
/// `functions/auth` callables).
library;

const int kPasswordMinLength = 8;
const int kPasswordMaxLength = 128;

final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'[0-9]');
final _sixDigits = RegExp(r'^[0-9]{6}$');

/// 8–128 characters with at least one letter and one digit.
bool isValidPassword(String password) =>
    password.length >= kPasswordMinLength &&
    password.length <= kPasswordMaxLength &&
    _letter.hasMatch(password) &&
    _digit.hasMatch(password);

/// The emailed verification code: exactly six digits (spaces ignored).
String? normalizeEmailCode(String input) {
  final code = input.replaceAll(RegExp(r'\s'), '');
  return _sixDigits.hasMatch(code) ? code : null;
}
