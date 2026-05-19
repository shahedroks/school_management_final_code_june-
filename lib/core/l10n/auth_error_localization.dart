import 'package:high_school/core/l10n/app_translations.dart';

/// Maps known English messages from the API or client validation to [auth.*] keys.
/// Returns [raw] when no mapping exists and [language] is English, so details stay visible.
/// For other languages, shows a generic translated message when the text is still English.
String localizedAuthApiMessage(AppLanguage language, String raw) {
  final key = _authErrorKey(raw);
  if (key != null) return t(language, 'auth.$key');

  if (_isLikelyEnglishOnly(raw)) {
    if (language == AppLanguage.en) return raw;
    return t(language, 'auth.unexpectedAuthError');
  }

  return raw;
}

bool _isLikelyEnglishOnly(String s) {
  for (final r in s.runes) {
    if (r > 0x7f) return false;
  }
  return true;
}

String? _authErrorKey(String raw) {
  var n = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  while (n.endsWith('.')) {
    n = n.substring(0, n.length - 1).trim();
  }
  if (n.isEmpty) return null;

  const exact = <String, String>{
    'please provide a phone number': 'phoneRequiredLogin',
    'invalid credentials or account not approved yet.': 'loginFailedGeneric',
    'invalid credentials': 'loginInvalidCredentials',
    'invalid credential': 'loginInvalidCredentials',
    'unauthorized': 'loginInvalidCredentials',
    'request failed': 'requestFailed',
    'invalid response': 'invalidResponse',
    'no data in response': 'noDataInResponse',
    'no token in response': 'noTokenInResponse',
    'no user in response': 'noUserInResponse',
    'failed to send otp': 'failedToSendOtp',
    'invalid otp': 'invalidOtp',
    'pins do not match': 'pinMismatch',
    'pin must be exactly 4 digits': 'pinMustBe4Digits',
    'otp must be exactly 4 digits': 'otpMustBe4Digits',
    'please select your grade': 'selectGradePrompt',
    'please select at least one subject': 'selectAtLeastOneSubject',
    'please enter your subject': 'enterSubjectPrompt',
    'phone number already registered': 'phoneAlreadyRegistered',
    'select at least one grade': 'selectAtLeastOneGrade',
  };

  final direct = exact[n];
  if (direct != null) return direct;

  if (n.contains('invalid') && n.contains('credential')) {
    return 'loginInvalidCredentials';
  }
  if (n.contains('pending') && (n.contains('approv') || n.contains('admin'))) {
    return 'accountPendingApproval';
  }
  if (n.contains('wrong') && n.contains('pin')) return 'loginInvalidCredentials';
  if (n.contains('incorrect') && n.contains('pin')) {
    return 'loginInvalidCredentials';
  }
  if (n.contains('phone') &&
      (n.contains('already') || n.contains('exist') || n.contains('taken'))) {
    return 'phoneAlreadyRegistered';
  }

  return null;
}
