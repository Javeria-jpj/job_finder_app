import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/applications_controller.dart';
import '../models/job.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'chips.dart';

/// Job listing as it appears in the feed, search results and saved list.
///
/// Layout follows the design: logo, title, company · location, skill chips,
/// salary, then a full-width action — "Quick Apply" until the user has
/// applied, "View Details" afterwards.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final applied = context.select<ApplicationsController, bool>(
      (controller) => controller.hasApplied(job.id),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyLogo(job: job),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.base,
                        children: [
                          Text(
                            job.company,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                job.location,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.base,
              runSpacing: AppSpacing.base,
              children: [
                for (final skill in job.skills.take(3)) SkillChip(label: skill),
                if (job.type != null) MetaChip(label: job.type!.label),
                if (job.workMode != null) MetaChip(label: job.workMode!.label),
                if (job.salaryRange case final salary?)
                  MetaChip(label: salary, icon: Icons.payments_outlined),
              ],
            ),
            const SizedBox(height: AppSpacing.gutter),
            if (applied)
              OutlinedButton(
                onPressed: onTap,
                child: const Text('View Details'),
              )
            else
              FilledButton(onPressed: onTap, child: const Text('Quick Apply')),
          ],
        ),
      ),
    );
  }
}

/// Company logo, falling back to initials when there is no image.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.job, this.size = 56});

  final Job job;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final initials = Text(
      job.companyInitials,
      style: theme.textTheme.titleMedium?.copyWith(
        color: AppColors.secondary,
        fontWeight: FontWeight.w700,
      ),
    );

    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: job.logoUrl == null
          ? initials
          : Image.network(
              job.logoUrl!,
              height: size,
              width: size,
              fit: BoxFit.contain,
              errorBuilder: (context, _, _) => Center(child: initials),
            ),
    );
  }
}
