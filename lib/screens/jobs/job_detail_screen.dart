import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/applications_controller.dart';
import '../../data/saved_jobs_controller.dart';
import '../../models/job.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chips.dart';
import '../../widgets/job_card.dart';

/// Full listing: header card, about, requirements, benefits, and a persistent
/// bottom bar with save + apply.
class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.job});

  final Job job;

  static const _benefits = <(IconData, String)>[
    (Icons.health_and_safety_outlined, 'Full Healthcare'),
    (Icons.savings_outlined, 'Pension Match'),
    (Icons.flight_takeoff, 'Paid Time Off'),
    (Icons.laptop_mac, 'Home Office Stipend'),
    (Icons.school_outlined, 'Learning Budget'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: () => _share(context),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Copy link',
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.base,
              AppSpacing.gutter,
              AppSpacing.md,
            ),
            children: [
              _HeaderCard(job: job),
              const SizedBox(height: AppSpacing.gutter),
              SectionCard(
                title: 'About the Role',
                child: Text(
                  job.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (job.responsibilities.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.gutter),
                SectionCard(
                  title: 'Requirements',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in job.responsibilities)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.gutter,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 20,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  item,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Benefits & Perks',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              // Typical package, not employer-specific: the job APIs do not
              // publish structured benefits.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (icon, label) in _benefits)
                    _BenefitTile(icon: icon, label: label),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ApplyBar(job: job),
    );
  }

  void _share(BuildContext context) {
    final url = job.applyUrl;
    final messenger = ScaffoldMessenger.of(context);
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This listing has no shareable link.')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: url));
    messenger.showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard.')),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(job: job, size: 64),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      job.company,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job.location,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.gutter),
          Wrap(
            spacing: AppSpacing.base,
            runSpacing: AppSpacing.base,
            children: [
              if (job.type != null)
                MetaChip(
                  label: job.type!.label,
                  icon: Icons.work_outline,
                  tinted: true,
                ),
              if (job.workMode != null)
                MetaChip(label: job.workMode!.label, icon: Icons.laptop_mac),
              if (job.salaryRange case final salary?)
                MetaChip(label: salary, icon: Icons.payments_outlined),
              MetaChip(
                label: 'Posted ${job.postedLabel.toLowerCase()}',
                icon: Icons.schedule,
              ),
            ],
          ),
          if (job.skills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.gutter),
            Wrap(
              spacing: AppSpacing.base,
              runSpacing: AppSpacing.base,
              children: [
                for (final skill in job.skills) SkillChip(label: skill),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.gutter,
        ),
        child: Column(
          children: [
            Container(
              height: 36,
              width: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppColors.secondary),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom bar: bookmark toggle plus the primary apply action.
class _ApplyBar extends StatelessWidget {
  const _ApplyBar({required this.job});

  final Job job;

  Future<void> _apply(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final applications = context.read<ApplicationsController>();
    final url = job.applyUrl;

    final isNew = applications.apply(job);

    if (url == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isNew
                ? 'Added to your applications. This sample listing has no '
                      'external link.'
                : 'Already in your applications.',
          ),
        ),
      );
      return;
    }

    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((Object _) => false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          launched
              ? 'Tracked in Applications. Finish applying in the tab that '
                    'just opened.'
              : 'Could not open the application page.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = context.select<SavedJobsController, bool>(
      (controller) => controller.isSaved(job.id),
    );
    final applied = context.select<ApplicationsController, bool>(
      (controller) => controller.hasApplied(job.id),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: IconButton(
                onPressed: () =>
                    context.read<SavedJobsController>().toggle(job),
                icon: Icon(
                  saved ? Icons.bookmark : Icons.bookmark_border,
                  color: saved ? AppColors.secondary : null,
                ),
                tooltip: saved ? 'Remove bookmark' : 'Save job',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () => _apply(context),
                child: Text(applied ? 'Applied · Open Again' : 'Apply Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
