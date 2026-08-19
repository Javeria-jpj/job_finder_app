import '../models/job.dart';
import 'job_repository.dart';

/// Built-in listings used when no `JOBS_API_TOKEN` is supplied, so the app is
/// fully usable without an API key.
class SampleJobRepository implements JobRepository {
  /// Simulates network latency so loading states are exercised.
  static const _delay = Duration(milliseconds: 350);

  @override
  Future<List<Job>> fetchJobs({String query = '', JobType? type}) async {
    await Future<void>.delayed(_delay);

    final normalized = query.trim().toLowerCase();

    return _jobs.where((job) {
      if (type != null && job.type != type) return false;
      if (normalized.isEmpty) return true;
      return job.title.toLowerCase().contains(normalized) ||
          job.company.toLowerCase().contains(normalized) ||
          job.location.toLowerCase().contains(normalized) ||
          job.skills.any((s) => s.toLowerCase().contains(normalized));
    }).toList();
  }

  @override
  Future<void> refresh() async {}

  static const List<Job> _jobs = [
    Job(
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
      description:
          'Build and ship cross-platform mobile apps used by thousands of '
          'customers daily. You will own features end to end, from design '
          'review through release.',
      responsibilities: [
        'Develop new features in Flutter for Android and iOS',
        'Integrate REST and Firebase backends',
        'Write widget and integration tests',
        'Review pull requests from other mobile engineers',
      ],
      skills: ['Flutter', 'Dart', 'Firebase', 'REST APIs', 'Git'],
    ),
    Job(
      id: 'j2',
      title: 'Junior Frontend Engineer',
      company: 'Systems Limited',
      location: 'Karachi, Pakistan',
      type: JobType.fullTime,
      workMode: WorkMode.onsite,
      minSalary: 90000,
      maxSalary: 140000,
      salaryCurrency: 'PKR',
      salaryUnit: 'MONTH',
      postedDaysAgo: 3,
      description:
          'Join a product team building dashboards for enterprise clients. '
          'Ideal for someone with strong fundamentals who wants mentorship.',
      responsibilities: [
        'Translate Figma designs into responsive interfaces',
        'Work with designers on accessibility and usability',
        'Fix bugs reported by QA within agreed SLAs',
      ],
      skills: ['React', 'TypeScript', 'CSS', 'Figma'],
    ),
    Job(
      id: 'j3',
      title: 'Mobile App Intern',
      company: 'Arbisoft',
      location: 'Remote',
      type: JobType.internship,
      workMode: WorkMode.remote,
      minSalary: 40000,
      maxSalary: 60000,
      salaryCurrency: 'PKR',
      salaryUnit: 'MONTH',
      postedDaysAgo: 0,
      description:
          'A six-month paid internship for final-year students. You will pair '
          'with senior engineers on a live product.',
      responsibilities: [
        'Ship small features under mentorship',
        'Write unit tests for existing modules',
        'Present your work in the weekly demo',
      ],
      skills: ['Flutter', 'Kotlin', 'Problem solving'],
    ),
    Job(
      id: 'j4',
      title: 'Backend Engineer (Node.js)',
      company: 'Tkxel',
      location: 'Islamabad, Pakistan',
      type: JobType.fullTime,
      workMode: WorkMode.hybrid,
      minSalary: 200000,
      maxSalary: 350000,
      salaryCurrency: 'PKR',
      salaryUnit: 'MONTH',
      postedDaysAgo: 6,
      description:
          'Design and scale the APIs powering our logistics platform, handling '
          'millions of requests each day.',
      responsibilities: [
        'Design REST and GraphQL endpoints',
        'Optimise PostgreSQL queries and indexes',
        'Own services in production, including on-call rotation',
      ],
      skills: ['Node.js', 'PostgreSQL', 'Docker', 'AWS'],
    ),
    Job(
      id: 'j5',
      title: 'UI/UX Designer',
      company: 'Contour Software',
      location: 'Lahore, Pakistan',
      type: JobType.contract,
      workMode: WorkMode.remote,
      minSalary: 120000,
      maxSalary: 180000,
      salaryCurrency: 'PKR',
      salaryUnit: 'MONTH',
      postedDaysAgo: 9,
      description:
          'Six-month contract to redesign our customer portal, with a strong '
          'possibility of extension.',
      responsibilities: [
        'Run discovery interviews with existing customers',
        'Produce wireframes and high-fidelity prototypes',
        'Maintain and extend the design system',
      ],
      skills: ['Figma', 'Design systems', 'User research', 'Prototyping'],
    ),
    Job(
      id: 'j6',
      title: 'QA Automation Engineer',
      company: 'Devsinc',
      location: 'Lahore, Pakistan',
      type: JobType.partTime,
      workMode: WorkMode.onsite,
      minSalary: 70000,
      maxSalary: 110000,
      salaryCurrency: 'PKR',
      salaryUnit: 'MONTH',
      postedDaysAgo: 14,
      description:
          'Part-time role building the automated regression suite for our '
          'e-commerce products.',
      responsibilities: [
        'Write end-to-end tests with Playwright',
        'Triage nightly test failures',
        'Report coverage gaps to the product team',
      ],
      skills: ['Playwright', 'JavaScript', 'CI/CD'],
    ),
  ];
}
