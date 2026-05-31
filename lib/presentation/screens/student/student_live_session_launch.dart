import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:high_school/core/utils/live_session_join_policy.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

Future<void> launchStudentLiveSessionLink(
  BuildContext context,
  LanguageProvider lang,
  LiveSessionEntity session,
) async {
  final raw = session.link.trim();
  if (raw.isEmpty) {
    _showLinkError(context, lang);
    return;
  }

  late final Uri uri;
  try {
    var parsed = Uri.parse(raw);
    if (!parsed.hasScheme) parsed = Uri.parse('https://$raw');
    uri = parsed;
  } catch (_) {
    if (context.mounted) _showLinkError(context, lang);
    return;
  }

  if (!context.mounted) return;
  try {
    var launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
    if (!launched && context.mounted) _showLinkError(context, lang);
  } catch (_) {
    if (context.mounted) _showLinkError(context, lang);
  }
}

void _showLinkError(BuildContext context, LanguageProvider lang) {
  const k = 'live.openLinkFailed';
  final t = lang.t(k);
  final msg = (t == k || t.isEmpty)
      ? 'Could not open the meeting link. Check the URL or try again in a browser.'
      : t;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
}

String studentJoinOpensMessage(LanguageProvider lang, LiveSessionEntity session) {
  const key = 'live.joinOpensAt';
  final template = lang.t(key);
  const fallback = 'Join opens {datetime} (5 minutes before start)';
  final text = (template == key || template.isEmpty) ? fallback : template;
  final hint = LiveSessionJoinPolicy.joinOpensHint(session);
  if (hint.isEmpty) {
    const k2 = 'live.joinNotYetAvailable';
    final t2 = lang.t(k2);
    return (t2 == k2 || t2.isEmpty)
        ? 'Join opens 5 minutes before the session starts'
        : t2;
  }
  return text.replaceAll('{datetime}', hint);
}
