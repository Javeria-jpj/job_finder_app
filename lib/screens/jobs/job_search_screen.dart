import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/job_repository.dart';
import '../../models/job.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/job_card.dart';
import '../../widgets/state_views.dart';
import 'job_detail_screen.dart';
import 'jobs_feed_screen.dart';

/// Search tab: the same listings, reached by keyword rather than by browsing.
class JobSearchScreen extends StatefulWidget {
  const JobSearchScreen({super.key});

  @override
  State<JobSearchScreen> createState() => _JobSearchScreenState();
}

class _JobSearchScreenState extends State<JobSearchScreen> {
  final _controller = TextEditingController();
  late final JobRepository _repository = context.read<JobRepository>();

  Timer? _debounce;
  Future<List<Job>>? _resultsFuture;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    setState(() {
      _resultsFuture = query.isEmpty
          ? null
          : _repository.fetchJobs(query: query);
    });
  }

  void _onChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _search();
    });
  }

  void _searchFor(String term) {
    _controller.text = term;
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Search'), centerTitle: false),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: JobSearchField(
                    controller: _controller,
                    autofocus: true,
                    hint: 'Job title, company or skill',
                    onChanged: _onChanged,
                    onSubmitted: (_) => _search(),
                    onClear: () {
                      _controller.clear();
                      _search();
                    },
                  ),
                ),
                Expanded(
                  child: _resultsFuture == null
                      ? _SearchSuggestions(onSelected: _searchFor)
                      : FutureBuilder<List<Job>>(
                          future: _resultsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (snapshot.hasError) {
                              final error = snapshot.error;
                              return EmptyStateView(
                                icon: Icons.wifi_off,
                                title: 'Search failed',
                                message: error is JobFetchException
                                    ? error.message
                                    : 'Please try again.',
                                action: FilledButton(
                                  onPressed: _search,
                                  child: const Text('Retry'),
                                ),
                              );
                            }

                            final jobs = snapshot.data ?? const <Job>[];
                            if (jobs.isEmpty) {
                              return const EmptyStateView(
                                icon: Icons.search_off,
                                title: 'No results',
                                message: 'Try a different keyword.',
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.gutter,
                                0,
                                AppSpacing.gutter,
                                AppSpacing.md,
                              ),
                              itemCount: jobs.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      '${jobs.length} '
                                      '${jobs.length == 1 ? 'result' : 'results'}',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  );
                                }
                                final job = jobs[index - 1];
                                return JobCard(
                                  job: job,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => JobDetailScreen(job: job),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the Search tab shows before a query has been typed.
///
/// Somewhere to start rather than a placeholder: keyword chips for a quick
/// tap, then category tiles big enough to aim at.
class _SearchSuggestions extends StatelessWidget {
  const _SearchSuggestions({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const List<String> _popular = [
    'Flutter',
    'Engineer',
    'Designer',
    'Remote',
    'Marketing',
    'Data',
  ];

  static const List<(IconData, String)> _categories = [
    (Icons.code, 'Engineering'),
    (Icons.brush_outlined, 'Design'),
    (Icons.campaign_outlined, 'Marketing'),
    (Icons.payments_outlined, 'Finance'),
    (Icons.support_agent, 'Sales'),
    (Icons.health_and_safety_outlined, 'Healthcare'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three columns once there is room, two otherwise. Fixing the count
        // keeps the tiles a sensible size rather than letting them stretch.
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        final available =
            constraints.maxWidth -
            AppSpacing.gutter * 2 -
            AppSpacing.sm * (columns - 1);
        final cardWidth = available / columns;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.base,
            AppSpacing.gutter,
            AppSpacing.md,
          ),
          children: [
            Text('Search for a role', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick a keyword below, or type anything above.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Popular searches', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.base,
              runSpacing: AppSpacing.base,
              children: [
                for (final term in _popular)
                  _SuggestionChip(label: term, onTap: () => onSelected(term)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Browse by category', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (icon, label) in _categories)
                  SizedBox(
                    width: cardWidth,
                    child: _CategoryCard(
                      icon: icon,
                      label: label,
                      onTap: () => onSelected(label),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Keyword chip, sized to its label.
///
/// Not [FilterPill]: that one centres its child, which makes it expand to
/// whatever box it is given, so in a [Wrap] every pill became a full-width
/// row of its own.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.full);

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.base),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable category tile: an icon badge above a label.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 22, color: AppColors.secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
