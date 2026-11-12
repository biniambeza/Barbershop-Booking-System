/// Ethiopian mobile number helpers.
///
/// Ethio Telecom numbers start with 9 and Safaricom Ethiopia numbers start
/// with 7, both followed by 8 more digits. Accepted input forms include
/// `0911223344`, `911223344`, `+251911223344`, `251911223344` and
/// `00251911223344`, with optional spaces, dashes, dots or parentheses.
library;

final RegExp _localMobile = RegExp(r'^[79]\d{8}$');

/// Returns the number in E.164 form (`+2519XXXXXXXX`), or null if the input
/// is not a valid Ethiopian mobile number.
String? normalizeEthiopianPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[\s\-().]'), '');
  if (digits.startsWith('+')) {
    digits = digits.substring(1);
  } else if (digits.startsWith('00')) {
    digits = digits.substring(2);
  }

  if (digits.startsWith('251')) {
    digits = digits.substring(3);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }

  if (!_localMobile.hasMatch(digits)) return null;
  return '+251$digits';
}

/// Formats an E.164 Ethiopian number for display: `+251 91 122 3344`.
/// Returns the input unchanged if it is not a valid Ethiopian mobile number.
String formatEthiopianPhone(String phone) {
  final normalized = normalizeEthiopianPhone(phone);
  if (normalized == null) return phone;
  final local = normalized.substring(4);
  return '+251 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
}
