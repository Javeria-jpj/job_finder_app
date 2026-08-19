import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/data/applications_controller.dart';
import 'package:job_finder_app/data/job_repository.dart';
import 'package:job_finder_app/data/sample_job_repository.dart';
import 'package:job_finder_app/data/saved_jobs_controller.dart';
import 'package:job_finder_app/models/job.dart';
import 'package:job_finder_app/models/job_application.dart';
import 'package:job_finder_app/screens/applications/applications_screen.dart';
import 'package:job_finder_app/screens/jobs/job_detail_screen.dart';
import 'package:job_finder_app/screens/jobs/job_search_screen.dart';
import 'package:job_finder_app/screens/jobs/jobs_feed_screen.dart';
import 'package:job_finder_app/screens/jobs/saved_jobs_screen.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Render checks for every signed-in screen.
///
/// A layout error (unbounded constraints, overflow) throws during pump, so
/// these fail loudly instead of the app showing a blank page in the browser.
void main() {
  late SavedJobsController saved;
  late ApplicationsController applications;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    saved = SavedJobsController(prefs)..loadFor('user-1');
    applications = ApplicationsController(prefs)..loadFor('user-1');
  });

  Widget wrap(Widget screen) {
    return MultiProvider(
      providers: [
        Provider<JobRepository>(create: (_) => SampleJobRepository()),
        ChangeNotifierProvider<SavedJobsController>.value(value: saved),
        ChangeNotifierProvider<ApplicationsController>.value(
          value: applications,
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: screen),
    );
  }

  // Built inline rather than fetched: SampleJobRepository delays its future,
  // and a real delay never completes inside testWidgets' fake async.
  const job = Job(
    id: 'j1',
    title: 'Flutter Developer',
    company: 'Netsol Technologies',
    location: 'Lahore, Pakistan',
    type: JobType.fullTime,
    workMode: WorkMode.hybrid,
    minSalary: 150000,
    maxSalary: 250000,
    salaryCurrency: 'PKR',
    salaryUnit: 'MONTH',
    postedDaysAgo: 1,
    description: 'Build cross-platform apps.',
    responsibilities: ['Ship features', 'Write tests'],
    skills: ['Flutter', 'Dart'],
  );

  testWidgets('job feed renders listings, search and filters', (tester) async {
    await tester.pumpWidget(wrap(const JobsFeedScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Career Connect'), findsOneWidget);
    expect(find.text('For You'), findsOneWidget);
    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('Quick Apply'), findsWidgets);
  });

  testWidgets('feed filter narrows the results', (tester) async {
    await tester.pumpWidget(wrap(const JobsFeedScreen()));
    await tester.pumpAndSettle();

    // "Remote" is the second pill, so it is on screen at the test viewport
    // width without scrolling the filter row.
    await tester.tap(find.text('Remote'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile App Intern'), findsOneWidget);
    expect(
      find.text('Flutter Developer'),
      findsNothing,
      reason: 'hybrid roles are excluded by the Remote filter',
    );
  });

  testWidgets('search screen starts with suggestions', (tester) async {
    await tester.pumpWidget(wrap(const JobSearchScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Search for a role'), findsOneWidget);
    expect(find.text('Popular searches'), findsOneWidget);
    expect(find.text('Browse by category'), findsOneWidget);
    expect(find.text('Engineering'), findsOneWidget);
  });

  testWidgets('tapping a suggestion runs that search', (tester) async {
    await tester.pumpWidget(wrap(const JobSearchScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Designer'));
    await tester.pumpAndSettle();

    // The suggestions give way to results for the tapped term.
    expect(find.text('Popular searches'), findsNothing);
    expect(find.widgetWithText(TextField, 'Designer'), findsOneWidget);
  });

  testWidgets('suggestion chips sit side by side, not stacked', (tester) async {
    await tester.pumpWidget(wrap(const JobSearchScreen()));
    await tester.pumpAndSettle();

    // The old pills centred their child, so each one stretched to the full
    // width and every chip landed on its own row.
    final flutterChip = tester.getRect(find.text('Flutter'));
    final engineerChip = tester.getRect(find.text('Engineer'));
    expect(
      flutterChip.top,
      engineerChip.top,
      reason: 'the first two chips share a row',
    );
  });

  testWidgets('job details renders every section', (tester) async {
    await tester.pumpWidget(wrap(JobDetailScreen(job: job)));
    await tester.pumpAndSettle();

    expect(find.text('Job Details'), findsOneWidget);
    expect(find.text('About the Role'), findsOneWidget);
    expect(find.text('Requirements'), findsOneWidget);
    expect(find.text('Apply Now'), findsOneWidget);

    // Benefits sit below the fold at the test viewport size.
    await tester.scrollUntilVisible(find.text('Benefits & Perks'), 300);
    expect(find.text('Benefits & Perks'), findsOneWidget);
  });

  testWidgets('applying from the detail screen records the application', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(JobDetailScreen(job: job)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apply Now'));
    await tester.pump();

    expect(applications.hasApplied(job.id), isTrue);
    expect(find.text('Applied · Open Again'), findsOneWidget);
  });

  testWidgets('bookmarking from the detail screen saves the job', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(JobDetailScreen(job: job)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pump();

    expect(saved.isSaved(job.id), isTrue);
  });

  testWidgets('applications tracker shows empty state, then sections', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ApplicationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No applications yet'), findsOneWidget);

    applications.apply(job);
    await tester.pumpAndSettle();

    expect(find.text('My Applications'), findsOneWidget);
    expect(find.text('Applied'), findsWidgets);

    applications.setStage(job.id, ApplicationStage.interviewing);
    await tester.pumpAndSettle();
    expect(find.text('Interviewing'), findsWidgets);
  });

  testWidgets('saved jobs screen renders both states', (tester) async {
    await tester.pumpWidget(wrap(const SavedJobsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Nothing saved yet'), findsOneWidget);

    saved.toggle(job);
    await tester.pumpAndSettle();

    expect(find.text('Flutter Developer'), findsOneWidget);
  });
}
