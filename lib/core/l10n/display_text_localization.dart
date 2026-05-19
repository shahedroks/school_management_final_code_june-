import 'package:high_school/core/l10n/app_translations.dart';

/// Maps common API subject names to [subjects.*] translation keys.
const Map<String, String> _subjectKeyByName = {
  'english': 'english',
  'mathematics': 'mathematics',
  'math': 'mathematics',
  'maths': 'mathematics',
  'physics': 'physics',
  'chemistry': 'chemistry',
  'french': 'french',
  'arabic': 'arabic',
  'svt': 'svt',
  'life and earth sciences': 'svt',
  'science': 'science',
  'history': 'history',
  'geography': 'geography',
  'biology': 'biology',
  'computer science': 'computerScience',
  'informatics': 'computerScience',
};

/// Localizes known school subject labels from the API; returns [raw] when unknown.
String localizedSubject(AppLanguage language, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final key = _subjectKeyByName[trimmed.toLowerCase()];
  if (key == null) return trimmed;
  final translated = t(language, 'subjects.$key');
  return translated == 'subjects.$key' ? trimmed : translated;
}

/// Localizes empty / placeholder strings often returned by the API in English.
String localizedDisplayValue(AppLanguage language, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  if (lower == 'not provided' ||
      lower == 'n/a' ||
      lower == 'na' ||
      lower == 'none' ||
      lower == 'null' ||
      lower == '-') {
    final translated = t(language, 'common.notProvided');
    return translated == 'common.notProvided' ? trimmed : translated;
  }
  return trimmed;
}
