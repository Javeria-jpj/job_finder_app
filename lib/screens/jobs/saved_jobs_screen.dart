import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/saved_jobs_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/job_card.dart';
import '../../widgets/state_views.dart';
import 'job_detail_screen.dart';

/// Bookmarked jobs, served from local storage (mirrored to Firestore), so the
/// screen works offline and never waits on the network.
class SavedJobsScreen extends StatelessWidget {
  const SavedJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SavedJobsController>();
    final jobs = controller.savedJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Jobs'),
        bottom: controller.syncError == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Container(
                  width: double.infinity,
                  color: AppColors.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                    vertical: AppSpacing.base,
                  ),
                  child: Text(
                    controller.syncError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onErrorContainer,
                    ),
                  ),
                ),
              ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: jobs.isEmpty
              ? const EmptyStateView(
                  icon: Icons.bookmark_border,
                  title: 'Nothing saved yet',
                  message: 'Tap the bookmark on any job to keep it here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.gutter,
                    AppSpacing.gutter,
                    AppSpacing.md,
                  ),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return JobCard(
                      job: job,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => JobDetailScreen(job: job),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
