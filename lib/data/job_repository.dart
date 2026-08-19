import '../models/job.dart';
import 'arbeitnow_repository.dart';
import 'fantastic_jobs_repository.dart';
import 'sample_job_repository.dart';

/// Raised when jobs cannot be loaded; [message] is safe to show to the user.
class JobFetchException implements Exception {
  const JobFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where job listings come from. The UI depends only on this interface, so the
/// backing service can change without touching a screen.
abstract class JobRepository {
  /// Optional Fantastic.jobs bearer token:
  ///
  ///     flutter run --dart-define=JOBS_API_TOKEN=your_token
  static const String fantasticJobsToken = String.fromEnvironment(
    'JOBS_API_TOKEN',
  );

  /// Forces the built-in listings, useful offline:
  ///
  ///     flutter run --dart-define=USE_SAMPLE_JOBS=true
  static const bool forceSampleData = bool.fromEnvironment('USE_SAMPLE_JOBS');

  /// Builds the repository the app should use. Defaults to the free, keyless
  /// Arbeitnow board so the app works with no configuration at all.
  static JobRepository create() {
    if (forceSampleData) return SampleJobRepository();
    if (fantasticJobsToken.isNotEmpty) {
      return FantasticJobsRepository(token: fantasticJobsToken);
    }
    return ArbeitnowRepository();
  }

  static bool get usingSampleData => forceSampleData;

  Future<List<Job>> fetchJobs({String query, JobType? type});

  /// Drops any cached listings so the next fetch hits the network.
  Future<void> refresh();
}
