import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/job.dart';
import '../utils/html_text.dart';
import 'job_repository.dart';

/// Live listings from the Fantastic.jobs API.
///
/// Docs: https://developer.fantastic.jobs/api/new-jobs#job-board-jobs
/// Endpoint: GET https://data.fantastic.jobs/v1/active-jb
class FantasticJobsRepository implements JobRepository {
  FantasticJobsRepository({required this.token, http.Client? client})
    : _client = client ?? http.Client();

  final String token;
  final http.Client _client;

  static const _host = 'data.fantastic.jobs';
  static const _path = '/v1/active-jb';
  static const _pageSize = 50;

  @override
  Future<List<Job>> fetchJobs({String query = '', JobType? type}) async {
    final trimmed = query.trim();

    return _get({
      'limit': '$_pageSize',
      'time_frame': '7d',
      // Without this the response carries no description at all.
      'description_format': 'text',
      if (trimmed.isNotEmpty) 'title': trimmed,
      if (type != null) 'ai_employment_type': type.apiValue,
    });
  }

  /// Nothing is cached here — every fetch already hits the API.
  @override
  Future<void> refresh() async {}

  Future<List<Job>> _get(Map<String, dynamic> params) async {
    final uri = Uri.https(_host, _path, params);

    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      debugPrint('Fantastic.jobs request failed: $error');
      throw JobFetchException(
        kIsWeb
            // Browsers block cross-origin calls the API does not opt into.
            ? 'Could not reach the jobs API from the browser. This is usually '
                  'CORS — run the app on Android/Windows, or proxy the call '
                  'through your own backend.'
            : 'Could not reach the jobs API. Check your connection.',
      );
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 401:
      case 403:
        throw const JobFetchException(
          'The jobs API rejected the token. Check JOBS_API_TOKEN.',
        );
      case 429:
        throw const JobFetchException(
          'Jobs API rate limit reached. Try again shortly.',
        );
      default:
        throw JobFetchException(
          'Jobs API error ${response.statusCode}. Please try again.',
        );
    }

    final decoded = jsonDecode(response.body);
    final list = decoded is List
        ? decoded
        // Some deployments wrap the array in an object.
        : (decoded is Map<String, dynamic> ? decoded['data'] as List? : null);

    if (list == null) {
      throw const JobFetchException('Unexpected response from the jobs API.');
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(jobFromApiJson)
        .nonNulls
        .toList();
  }
}

/// Maps one Fantastic.jobs listing onto [Job]. Returns null for records
/// missing the fields the UI cannot do without.
@visibleForTesting
Job? jobFromApiJson(Map<String, dynamic> json) {
  final id = json['id']?.toString();
  final title = json['title'] as String?;
  final organization = json['organization'] as String?;
  if (id == null || title == null || organization == null) return null;

  return Job(
    id: id,
    title: title,
    company: organization,
    location: _location(json),
    type: JobType.fromApi(_firstString(json['ai_employment_type'])),
    workMode: WorkMode.fromApi(_firstString(json['ai_work_arrangement'])),
    minSalary: _toDouble(json['ai_salary_min_value']),
    maxSalary:
        _toDouble(json['ai_salary_max_value']) ??
        _toDouble(json['ai_salary_value']),
    salaryCurrency: json['ai_salary_currency'] as String?,
    salaryUnit: json['ai_salary_unit_text'] as String?,
    postedDaysAgo: _daysAgo(json['date_posted'] ?? json['date_created']),
    // description_text is meant to be plain, but listings still carry stray
    // markup and entities, so it goes through the same cleaner.
    description: htmlToPlainText(
      (json['description_text'] ?? json['description_html']) as String?,
      fallback: 'No description was provided for this listing.',
    ),
    responsibilities: _stringList(json['ai_core_responsibilities']),
    skills: _stringList(json['ai_key_skills']),
    applyUrl: json['url'] as String?,
    logoUrl: json['organization_logo'] as String?,
  );
}

String _location(Map<String, dynamic> json) {
  final derived = _stringList(json['locations_derived']);
  if (derived.isNotEmpty) return derived.first;

  final city = _firstString(json['cities_derived']);
  final country = _firstString(json['countries_derived']);
  final parts = [city, country].whereType<String>();
  if (parts.isNotEmpty) return parts.join(', ');

  // location_type is "TELECOMMUTE" for remote-only postings.
  if (json['location_type'] != null) return 'Remote';
  return 'Location not specified';
}

int _daysAgo(Object? raw) {
  if (raw is! String) return 0;
  final posted = DateTime.tryParse(raw);
  if (posted == null) return 0;
  final days = DateTime.now().toUtc().difference(posted.toUtc()).inDays;
  return days < 0 ? 0 : days;
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _firstString(Object? value) {
  if (value is String) return value;
  if (value is List) {
    for (final item in value) {
      if (item is String && item.isNotEmpty) return item;
    }
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is String) return value.isEmpty ? const [] : [value];
  if (value is List) {
    return value.whereType<String>().where((s) => s.isNotEmpty).toList();
  }
  return const [];
}
