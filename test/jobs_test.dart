import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/data/applications_controller.dart';
import 'package:job_finder_app/data/arbeitnow_repository.dart';
import 'package:job_finder_app/data/fantastic_jobs_repository.dart';
import 'package:job_finder_app/data/sample_job_repository.dart';
import 'package:job_finder_app/data/saved_jobs_controller.dart';
import 'package:job_finder_app/data/saved_jobs_sync.dart';
import 'package:job_finder_app/models/job.dart';
import 'package:job_finder_app/models/job_application.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:job_finder_app/widgets/job_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _job = Job(
  id: 'test',
  title: 'Flutter Developer',
  company: 'Netsol Technologies',
  location: 'Lahore, Pakistan',
  type: JobType.fullTime,
  workMode: WorkMode.hybrid,
  minSalary: 150000,
  maxSalary: 250000,
  salaryCurrency: 'PKR',
  salaryUnit: 'MONTH',
  postedDaysAgo: 3,
  description: 'Build apps.',
  responsibilities: ['Ship features'],
  skills: ['Flutter'],
);

/// In-memory stand-in for Firestore.
class FakeSavedJobsSync implements SavedJobsSync {
  final Map<String, Map<String, Job>> stored = {};
  final Map<String, StreamController<List<Job>>> _controllers = {};

  bool failWrites = false;

  @override
  Stream<List<Job>> watch(String userId) {
    stored.putIfAbsent(userId, () => {});
    final controller = _controllers.putIfAbsent(
      userId,
      () => StreamController<List<Job>>.broadcast(),
    );
    return controller.stream;
  }

  /// Simulates a snapshot arriving from the server.
  void emit(String userId, List<Job> jobs) {
    stored[userId] = {for (final job in jobs) job.id: job};
    _controllers[userId]?.add(jobs);
  }

  @override
  Future<void> save(String userId, Job job) async {
    if (failWrites) throw Exception('permission-denied');
    stored.putIfAbsent(userId, () => {})[job.id] = job;
  }

  @override
  Future<void> remove(String userId, String jobId) async {
    if (failWrites) throw Exception('permission-denied');
    stored[userId]?.remove(jobId);
  }
}

void main() {
  group('Job', () {
    test('formats a salary range with currency and unit', () {
      expect(_job.salaryRange, '150k - 250k PKR / month');
    });

    test('collapses a single-value salary', () {
      const job = Job(
        id: 'a',
        title: 't',
        company: 'c',
        location: 'l',
        maxSalary: 120000,
        salaryCurrency: 'USD',
        salaryUnit: 'YEAR',
        postedDaysAgo: 0,
        description: '',
        responsibilities: [],
        skills: [],
      );
      expect(job.salaryRange, '120k USD / year');
    });

    test('returns null when the listing has no salary', () {
      const job = Job(
        id: 'a',
        title: 't',
        company: 'c',
        location: 'l',
        postedDaysAgo: 0,
        description: '',
        responsibilities: [],
        skills: [],
      );
      expect(job.salaryRange, isNull);
    });

    test('formats how long ago a job was posted', () {
      expect(_job.postedLabel, '3 days ago');
    });

    test('builds initials from the company name', () {
      expect(_job.companyInitials, 'NT');
    });
  });

  group('SampleJobRepository', () {
    final repo = SampleJobRepository();

    test('returns every job when no filter is applied', () async {
      expect(await repo.fetchJobs(), isNotEmpty);
    });

    test('search matches title, location and skills', () async {
      expect(await repo.fetchJobs(query: 'flutter'), isNotEmpty);
      expect(await repo.fetchJobs(query: 'karachi'), isNotEmpty);
      expect(await repo.fetchJobs(query: 'zzzzz'), isEmpty);
    });

    test('type filter narrows the results', () async {
      final jobs = await repo.fetchJobs(type: JobType.internship);
      expect(jobs, isNotEmpty);
      expect(jobs.every((j) => j.type == JobType.internship), isTrue);
    });
  });

  group('jobFromApiJson', () {
    test('maps a Fantastic.jobs listing', () {
      final job = jobFromApiJson({
        'id': 12345,
        'title': 'Senior Flutter Engineer',
        'organization': 'Acme Inc',
        'organization_logo': 'https://example.com/logo.png',
        'url': 'https://example.com/jobs/1',
        'locations_derived': ['Berlin, Germany'],
        'ai_employment_type': ['FULL_TIME'],
        'ai_work_arrangement': ['Hybrid'],
        'ai_salary_min_value': 70000,
        'ai_salary_max_value': 90000,
        'ai_salary_currency': 'EUR',
        'ai_salary_unit_text': 'YEAR',
        'date_posted': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 2))
            .toIso8601String(),
        'description_text': 'Great role.',
        'ai_core_responsibilities': ['Build things'],
        'ai_key_skills': ['Flutter', 'Dart'],
      });

      expect(job, isNotNull);
      expect(job!.id, '12345');
      expect(job.company, 'Acme Inc');
      expect(job.location, 'Berlin, Germany');
      expect(job.type, JobType.fullTime);
      expect(job.workMode, WorkMode.hybrid);
      expect(job.salaryRange, '70k - 90k EUR / year');
      expect(job.postedLabel, '2 days ago');
      expect(job.skills, ['Flutter', 'Dart']);
      expect(job.applyUrl, 'https://example.com/jobs/1');
    });

    test('tolerates missing optional fields', () {
      final job = jobFromApiJson({
        'id': 7,
        'title': 'Intern',
        'organization': 'Startup',
        'location_type': 'TELECOMMUTE',
      });

      expect(job, isNotNull);
      expect(job!.location, 'Remote');
      expect(job.type, isNull);
      expect(job.salaryRange, isNull);
      expect(job.skills, isEmpty);
      expect(job.description, isNotEmpty);
    });

    test('drops records without an id, title or organization', () {
      expect(jobFromApiJson({'title': 'No id'}), isNull);
      expect(jobFromApiJson({'id': 1, 'title': 'No org'}), isNull);
    });

    test('maps unsupported employment types to null', () {
      expect(JobType.fromApi('VOLUNTEER'), isNull);
      expect(JobType.fromApi('CONTRACTOR'), JobType.contract);
      expect(WorkMode.fromApi('Remote Solely'), WorkMode.remote);
    });
  });

  group('jobFromArbeitnowJson', () {
    test('maps a listing from the live response shape', () {
      final job = jobFromArbeitnowJson({
        'slug': 'software-engineer-berlin-123',
        'title': 'Software Engineer',
        'company_name': 'Preiswecker',
        'location': 'Berlin',
        'remote': false,
        'job_types': ['Full-time'],
        'tags': ['Java', 'Spring'],
        'url': 'https://www.arbeitnow.com/jobs/123',
        'created_at':
            DateTime.now()
                .subtract(const Duration(days: 4))
                .millisecondsSinceEpoch ~/
            1000,
        'description': '<p>Build things.</p><ul><li>Ship code</li></ul>',
      });

      expect(job, isNotNull);
      expect(job!.id, 'software-engineer-berlin-123');
      expect(job.location, 'Berlin');
      expect(job.type, JobType.fullTime);
      expect(job.workMode, WorkMode.onsite);
      expect(job.skills, ['Java', 'Spring']);
      expect(job.postedLabel, '4 days ago');
      // HTML is stripped, list items become bullets.
      expect(job.description, contains('Build things.'));
      expect(job.description, contains('• Ship code'));
      expect(job.description, isNot(contains('<')));
    });

    test('falls back to Remote when no location is given', () {
      final job = jobFromArbeitnowJson({
        'slug': 'x',
        'title': 'Dev',
        'company_name': 'Acme',
        'location': '',
        'remote': true,
      });

      expect(job!.location, 'Remote');
      expect(job.workMode, WorkMode.remote);
    });

    test('drops records missing a slug, title or company', () {
      expect(jobFromArbeitnowJson({'title': 'No slug'}), isNull);
    });
  });

  group('SavedJobsController cloud sync', () {
    late FakeSavedJobsSync sync;
    late SavedJobsController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sync = FakeSavedJobsSync();
      controller = SavedJobsController(
        await SharedPreferences.getInstance(),
        sync: sync,
      );
    });

    tearDown(() => controller.dispose());

    test('saving a job writes it to the cloud', () async {
      controller.loadFor('user-1');
      controller.toggle(_job);
      await pumpEventQueue();

      expect(sync.stored['user-1']!.keys, ['test']);

      controller.toggle(_job);
      await pumpEventQueue();
      expect(sync.stored['user-1'], isEmpty);
    });

    test('a remote change updates the local list', () async {
      controller.loadFor('user-1');
      await pumpEventQueue();

      // As if the same account bookmarked this job on another device.
      sync.emit('user-1', [_job]);
      await pumpEventQueue();

      expect(controller.isSaved('test'), isTrue);
      expect(controller.count, 1);
    });

    test(
      'local-only bookmarks are uploaded, not erased, on first sync',
      () async {
        // Bookmarked earlier with no cloud sync — offline, or before Firestore
        // was wired up — so local storage has it and the account does not.
        final prefs = await SharedPreferences.getInstance();
        SavedJobsController(prefs)
          ..loadFor('user-1')
          ..toggle(_job)
          ..dispose();
        await pumpEventQueue();

        controller.loadFor('user-1');
        sync.emit('user-1', const []); // First snapshot: empty account.
        await pumpEventQueue();

        expect(controller.count, 1, reason: 'local bookmark must survive');
        expect(sync.stored['user-1']!.containsKey('test'), isTrue);
      },
    );

    test('reports an error instead of failing silently', () async {
      sync.failWrites = true;
      controller.loadFor('user-1');
      controller.toggle(_job);
      await pumpEventQueue();

      expect(controller.syncError, isNotNull);
      // The bookmark is still kept locally.
      expect(controller.isSaved('test'), isTrue);
    });
  });

  group('SavedJobsController', () {
    late SavedJobsController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      controller = SavedJobsController(await SharedPreferences.getInstance());
      controller.loadFor('user-1');
    });

    test('toggle adds then removes, and notifies listeners', () {
      var notifications = 0;
      void listener() => notifications++;
      controller.addListener(listener);
      addTearDown(() => controller.removeListener(listener));

      expect(controller.toggle(_job), isTrue);
      expect(controller.isSaved(_job.id), isTrue);
      expect(controller.count, 1);

      expect(controller.toggle(_job), isFalse);
      expect(controller.isSaved(_job.id), isFalse);
      expect(controller.count, 0);
      expect(notifications, 2);
    });

    test('bookmarks survive a restart', () async {
      controller.toggle(_job);

      // A fresh controller over the same storage, as after an app restart.
      final restarted = SavedJobsController(
        await SharedPreferences.getInstance(),
      )..loadFor('user-1');

      expect(restarted.count, 1);
      expect(restarted.savedJobs.single.title, _job.title);
    });

    test('each account gets its own bookmarks', () async {
      controller.toggle(_job);
      controller.loadFor('user-2');
      expect(controller.count, 0);

      controller.loadFor('user-1');
      expect(controller.count, 1);
    });
  });

  test('Job survives a JSON round trip', () {
    final restored = Job.fromJson(_job.toJson());
    expect(restored.id, _job.id);
    expect(restored.type, _job.type);
    expect(restored.workMode, _job.workMode);
    expect(restored.salaryRange, _job.salaryRange);
    expect(restored.skills, _job.skills);
  });

  testWidgets('JobCard shows the listing and its primary action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final applications = ApplicationsController(
      await SharedPreferences.getInstance(),
    )..loadFor('user-1');

    var taps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<ApplicationsController>.value(
        value: applications,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: JobCard(job: _job, onTap: () => taps++),
          ),
        ),
      ),
    );

    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('Netsol Technologies'), findsOneWidget);
    expect(find.text('Lahore, Pakistan'), findsOneWidget);
    expect(find.text('150k - 250k PKR / month'), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget); // skill chip

    // Not yet applied, so the card offers the primary action.
    expect(find.text('Quick Apply'), findsOneWidget);
    expect(find.text('View Details'), findsNothing);

    await tester.tap(find.text('Flutter Developer'));
    expect(taps, 1);

    // Once applied, the card switches to the secondary action.
    applications.apply(_job);
    await tester.pump();

    expect(find.text('View Details'), findsOneWidget);
    expect(find.text('Quick Apply'), findsNothing);
  });

  group('ApplicationsController', () {
    late ApplicationsController controller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      controller = ApplicationsController(await SharedPreferences.getInstance())
        ..loadFor('user-1');
    });

    test('applying is recorded once and starts at the Applied stage', () {
      expect(controller.apply(_job), isTrue);
      expect(controller.apply(_job), isFalse, reason: 'no duplicates');
      expect(controller.count, 1);
      expect(controller.hasApplied(_job.id), isTrue);
      expect(controller.forJob(_job.id)!.stage, ApplicationStage.applied);
    });

    test('stages can be advanced and counted', () {
      controller.apply(_job);
      controller.setStage(_job.id, ApplicationStage.interviewing);

      expect(controller.stageCount(ApplicationStage.interviewing), 1);
      expect(controller.stageCount(ApplicationStage.applied), 0);
      expect(
        controller.byStage(ApplicationStage.interviewing).single.job.id,
        _job.id,
      );
    });

    test('progress reflects the stage', () {
      expect(ApplicationStage.applied.progress, closeTo(1 / 3, 0.001));
      expect(ApplicationStage.offer.progress, 1.0);
    });

    test('applications survive a restart', () async {
      controller.apply(_job);
      controller.setStage(_job.id, ApplicationStage.offer);

      final restarted = ApplicationsController(
        await SharedPreferences.getInstance(),
      )..loadFor('user-1');

      expect(restarted.count, 1);
      expect(restarted.forJob(_job.id)!.stage, ApplicationStage.offer);
    });

    test('withdrawing removes it from the tracker', () {
      controller.apply(_job);
      controller.withdraw(_job.id);
      expect(controller.count, 0);
    });
  });
}
