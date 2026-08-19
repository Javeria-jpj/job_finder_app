import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/job_repository.dart';
import '../../models/job.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/job_card.dart';
import '../../widgets/state_views.dart';
import 'job_detail_screen.dart';

/// Quick filters shown as pills under the search bar.
enum FeedFilter {
  forYou('For You'),
  remote('Remote'),
  fullTime('Full-time', JobType.fullTime),
  contract('Contract', JobType.contract),
  partTime('Part-time', JobType.partTime),
  internship('Internship', JobType.internship);

  const FeedFilter(this.label, [this.type]);

  final String label;
  final JobType? type;
}

/// Home tab: search, quick filters and the job feed.
class JobsFeedScreen extends StatefulWidget {
  const JobsFeedScreen({super.key});

  @override
  State<JobsFeedScreen> createState() => _JobsFeedScreenState();
}

class _JobsFeedScreenState extends State<JobsFeedScreen> {
  final _searchController = TextEditingController();

  late final JobRepository _repository = context.read<JobRepository>();

  Timer? _debounce;
  FeedFilter _filter = FeedFilter.forYou;
  late Future<List<Job>> _jobsFuture = _load();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Job>> _load() async {
    final jobs = await _repository.fetchJobs(
      query: _searchController.text,
      type: _filter.type,
    );
    // The API has no "remote" parameter, so narrow it here.
    if (_filter == FeedFilter.remote) {
      return jobs.where((job) => job.workMode == WorkMode.remote).toList();
    }
    return jobs;
  }

  void _refresh() => setState(() => _jobsFuture = _load());

  Future<void> _reload() async {
    await _repository.refresh();
    if (!mounted) return;
    setState(() => _jobsFuture = _load());
    await _jobsFuture.catchError((Object _) => <Job>[]);
  }

  /// Repaints immediately for the clear button, but waits for a pause in
  /// typing before querying.
  void _onSearchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _refresh();
    });
  }

  void _setFilter(FeedFilter filter) {
    setState(() {
      _filter = filter;
      _jobsFuture = _load();
    });
  }

  void _openJob(Job job) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => JobDetailScreen(job: job)));
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          AppSpacing.gutter,
                          AppSpacing.gutter,
                          0,
                        ),
                        child: JobSearchField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _refresh(),
                          onClear: () {
                            _searchController.clear();
                            _refresh();
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.gutter,
                          ),
                          itemCount: FeedFilter.values.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.base),
                          itemBuilder: (context, index) {
                            final filter = FeedFilter.values[index];
                            return FilterPill(
                              label: filter.label,
                              selected: _filter == filter,
                              onTap: () => _setFilter(filter),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.gutter),
                      Expanded(
                        child: FutureBuilder<List<Job>>(
                          future: _jobsFuture,
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
                                title: 'Could not load jobs',
                                message: error is JobFetchException
                                    ? error.message
                                    : 'Please try again.',
                                action: FilledButton(
                                  onPressed: _refresh,
                                  child: const Text('Retry'),
                                ),
                              );
                            }

                            final jobs = snapshot.data ?? const <Job>[];
                            if (jobs.isEmpty) {
                              return const EmptyStateView(
                                icon: Icons.search_off,
                                title: 'No matching jobs',
                                message:
                                    'Try another keyword or a different filter.',
                              );
                            }

                            return RefreshIndicator(
                              onRefresh: _reload,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.gutter,
                                  0,
                                  AppSpacing.gutter,
                                  AppSpacing.md,
                                ),
                                itemCount: jobs.length,
                                itemBuilder: (context, index) {
                                  final job = jobs[index];
                                  return JobCard(
                                    job: job,
                                    onTap: () => _openJob(job),
                                  );
                                },
                              ),
                            );
                          },
                        ),
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

/// Prominent search field with a Level 1 shadow and an Action Blue icon.
class JobSearchField extends StatelessWidget {
  const JobSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.autofocus = false,
    this.hint = 'Search for jobs, companies, or keywords',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final bool autofocus;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppColors.level1,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, color: AppColors.secondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear search',
                  onPressed: onClear,
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped quick filter. Selected pills fill with Action Blue.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.secondary : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: selected ? AppColors.secondary : AppColors.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? AppColors.onSecondary
                  : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
