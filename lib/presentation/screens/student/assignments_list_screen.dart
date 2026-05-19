import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:high_school/domain/entities/assignment_entity.dart';
import 'package:high_school/domain/repositories/assignments_repository.dart';
import 'package:high_school/presentation/providers/language_provider.dart';

class AssignmentsListScreen extends StatelessWidget {
  const AssignmentsListScreen({super.key});

  static String _formatDueDate(String dueDateStr) {
    try {
      final d = DateTime.tryParse(dueDateStr);
      if (d == null) return dueDateStr;
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return dueDateStr;
    }
  }

  static String _statusLabel(LanguageProvider lang, AssignmentStatus status) {
    switch (status) {
      case AssignmentStatus.submitted:
        return lang.t('assignments.submitted');
      case AssignmentStatus.graded:
        return lang.t('assignments.graded');
      case AssignmentStatus.pending:
        return lang.t('assignments.pending').split(' ').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Container(
      color: Colors.grey.shade200,
      child: FutureBuilder<List<AssignmentEntity>>(
        future: context.read<AssignmentsRepository>().getAssignments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  lang.t('assignments.noAssignmentsAvailable'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => context.push('/student/assignments/${a.id}', extra: a),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF424242),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${lang.t('assignments.dueDate')}: ${_formatDueDate(a.dueDate)} · ${_statusLabel(lang, a.status)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
