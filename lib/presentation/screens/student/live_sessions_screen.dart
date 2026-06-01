import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/core/theme/app_theme.dart';
import 'package:high_school/core/utils/app_date_format.dart';
import 'package:high_school/core/utils/live_session_join_policy.dart';
import 'package:high_school/domain/entities/live_session_entity.dart';
import 'package:high_school/domain/entities/student_live_sessions_overview.dart';
import 'package:high_school/domain/repositories/live_sessions_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';
import 'package:high_school/presentation/screens/student/student_live_session_launch.dart';

class LiveSessionsScreen extends StatelessWidget {
  const LiveSessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final liveRepo = context.read<LiveSessionsRepository>();
    return FutureBuilder<StudentLiveSessionsOverview>(
      future: liveRepo.getStudentSessionsOverview(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final overview = snapshot.data!;
        final activeSessions = overview.active;
        final upcomingSessions = overview.upcoming;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header banner – match React
              Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang.t('live.liveSessions'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.t('live.upcomingSessions'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Active Now — running sessions (including late join within duration)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: activeSessions.isNotEmpty ? Colors.red : Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${lang.t('live.activeNow')} (${activeSessions.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeSessions.isEmpty)
              _EmptyActiveCard(lang: lang)
            else
              ...activeSessions.map((s) => _ActiveSessionCard(session: s, lang: lang)),
            const SizedBox(height: 20),
            // Upcoming Sessions section
            Text(
              '${lang.t('live.upcomingSessions')} (${upcomingSessions.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            if (upcomingSessions.isEmpty)
              _EmptyUpcomingCard(lang: lang)
            else
              ...upcomingSessions.map((s) => _UpcomingSessionCard(
                    session: s,
                    className: s.className ??
                        (s.subject != null && s.subject!.isNotEmpty
                            ? s.subject!
                            : 'Class'),
                    lang: lang,
                  )),
            const SizedBox(height: 24),
          ],
          ),
        );
      },
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final LiveSessionEntity session;
  final LanguageProvider lang;

  const _ActiveSessionCard({required this.session, required this.lang});

  @override
  Widget build(BuildContext context) {
    final platformStr = session.platform == LiveSessionPlatform.zoom ? 'Zoom' : 'Meet';
    final canJoin = LiveSessionJoinPolicy.canJoinNow(session);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.time} • $platformStr',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: canJoin
                  ? () => launchStudentLiveSessionLink(context, lang, session)
                  : () => context.go(
                        '/student/live-sessions/${session.id}',
                        extra: session,
                      ),
              icon: const Icon(Icons.video_call, size: 16),
              label: Text(lang.t('live.joinSession')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2e7d32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingSessionCard extends StatelessWidget {
  final LiveSessionEntity session;
  final String className;
  final LanguageProvider lang;

  const _UpcomingSessionCard({
    required this.session,
    required this.className,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final platformStr = session.platform == LiveSessionPlatform.zoom ? 'Zoom' : 'Meet';
    final canJoin = LiveSessionJoinPolicy.canJoinNow(session);
    final opensHint = studentJoinOpensMessage(lang, session);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: AppTheme.primary,
            child: InkWell(
              onTap: () => context.go(
                '/student/live-sessions/${session.id}',
                extra: session,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.video_call, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        className,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(AppDateFormat.date(session.date), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(width: 16),
                    Icon(Icons.schedule, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(session.time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    platformStr,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 14),
                if (canJoin)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => launchStudentLiveSessionLink(context, lang, session),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(lang.t('live.joinSession')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.45), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opensHint,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActiveCard extends StatelessWidget {
  final LanguageProvider lang;

  const _EmptyActiveCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.video_call, size: 32, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lang.t('live.noActiveSessions'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyUpcomingCard extends StatelessWidget {
  final LanguageProvider lang;

  const _EmptyUpcomingCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.video_call, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              lang.t('live.noUpcomingSessions'),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

