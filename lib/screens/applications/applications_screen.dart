import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/applications_controller.dart';
import '../../models/job_application.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/chips.dart';
import '../../widgets/state_views.dart';
import '../jobs/job_detail_screen.dart';

/// Tracker for everything the user has applied to, grouped by stage.
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<ApplicationsController>();

    final interviewing = controller.byStage(ApplicationStage.interviewing);
    final offers = controller.byStage(ApplicationStage.offer);
    final applied = controller.byStage(ApplicationStage.applied);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrandHeader(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: controller.count == 0
                      ? const EmptyStateView(
                          icon: Icons.assignment_outlined,
                          title: 'No applications yet',
                          message:
                              'Tap Apply on any job and it will show up here '
                              'so you can track its progress.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.gutter,
                            AppSpacing.md,
                            AppSpacing.gutter,
                            AppSpacing.md,
                          ),
                          children: [
                            Text(
                              'My Applications',
                              style: theme.textTheme.headlineLarge,
                            ),
                            const SizedBox(height: AppSpacing.base),
                            Text(
                              'Track and manage your ongoing job '
                              'opportunities.',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (interviewing.isNotEmpty)
                              _StageSection(
                                title: 'Interviewing',
                                applications: interviewing,
                              ),
                            if (offers.isNotEmpty)
                              _StageSection(
                                title: 'Offers',
                                applications: offers,
                              ),
                            if (applied.isNotEmpty)
                              _StageSection(
                                title: 'Applied',
                                applications: applied,
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageSection extends StatelessWidget {
  const _StageSection({required this.title, required this.applications});

  final String title;
  final List<JobApplication> applications;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.base),
        const Divider(),
        const SizedBox(height: AppSpacing.gutter),
        for (final application in applications)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
            child: _ApplicationCard(application: application),
          ),
        const SizedBox(height: AppSpacing.base),
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final job = application.job;
    final isOffer = application.stage == ApplicationStage.offer;

    return AppCard(
      color: isOffer ? AppColors.primaryFixed : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => JobDetailScreen(job: job)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${job.company} · ${job.location}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _StageMenu(application: application),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StatusChip(
                label: application.stage.label,
                background: isOffer
                    ? AppColors.secondary
                    : AppColors.secondaryFixed,
                foreground: isOffer
                    ? AppColors.onSecondary
                    : AppColors.onSecondaryContainer,
                icon: switch (application.stage) {
                  ApplicationStage.applied => Icons.send_outlined,
                  ApplicationStage.interviewing => Icons.videocam_outlined,
                  ApplicationStage.offer => Icons.celebration_outlined,
                },
              ),
              const SizedBox(width: AppSpacing.base),
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Applied ${application.appliedLabel}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: application.stage.progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final stage in ApplicationStage.values)
                Text(
                  stage.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: stage == application.stage
                        ? AppColors.secondary
                        : AppColors.onSurfaceVariant,
                    fontWeight: stage == application.stage
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stages are advanced by hand — there is no employer-side feed to read them
/// from, so the user records what happened.
class _StageMenu extends StatelessWidget {
  const _StageMenu({required this.application});

  final JobApplication application;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ApplicationsController>();
    final jobId = application.job.id;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Update status',
      onSelected: (value) {
        if (value == 'withdraw') {
          controller.withdraw(jobId);
          return;
        }
        controller.setStage(jobId, ApplicationStage.fromName(value));
      },
      itemBuilder: (context) => [
        for (final stage in ApplicationStage.values)
          PopupMenuItem(
            value: stage.name,
            enabled: stage != application.stage,
            child: Text('Mark as ${stage.label}'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'withdraw',
          child: Text('Remove from tracker'),
        ),
      ],
    );
  }
}
