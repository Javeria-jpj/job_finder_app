import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/job.dart';
import '../utils/html_text.dart';
import 'job_repository.dart';

/// Free, keyless job board API.
///
/// Docs: https://www.arbeitnow.com/api/job-board-api
///
/// The endpoint has no search parameter, so one page is fetched and cached,
/// then filtered locally. That also keeps request volume low.
class ArbeitnowRepository implements JobRepository {
  ArbeitnowRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _endpoint = Uri.https(
    'www.arbeitnow.com',
    '/api/job-board-api',
  );

  List<Job>? _cache;

  @override
  Future<List<Job>> fetchJobs({String query = '', JobType? type}) async {
    final jobs = _cache ??= await _download();
    final normalized = query.trim().toLowerCase();

    return jobs.where((job) {
      if (type != null && job.type != type) return false;
      if (normalized.isEmpty) return true;
      return job.title.toLowerCase().contains(normalized) ||
          job.company.toLowerCase().contains(normalized) ||
          job.location.toLowerCase().contains(normalized) ||
          job.skills.any((s) => s.toLowerCase().contains(normalized));
    }).toList();
  }

  @override
  Future<void> refresh() async => _cache = null;

  Future<List<Job>> _download() async {
    final http.Response response;
    try {
      response = await _client
          .get(_endpoint, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
    } catch (error) {
      debugPrint('Arbeitnow request failed: $error');
      throw const JobFetchException(
        'Could not reach the jobs service. Check your connection.',
      );
    }

    if (response.statusCode != 200) {
      throw JobFetchException(
        'Jobs service error ${response.statusCode}. Please try again.',
      );
    }

    final decoded = jsonDecode(response.body);
    final list = decoded is Map<String, dynamic>
        ? decoded['data'] as List?
        : null;
    if (list == null) {
      throw const JobFetchException('Unexpected response from the jobs API.');
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map(jobFromArbeitnowJson)
        .nonNulls
        .toList();
  }
}

/// Maps one Arbeitnow listing onto [Job]; null when required fields are absent.
@visibleForTesting
Job? jobFromArbeitnowJson(Map<String, dynamic> json) {
  final slug = json['slug'] as String?;
  final title = json['title'] as String?;
  final company = json['company_name'] as String?;
  if (slug == null || title == null || company == null) return null;

  final remote = json['remote'] == true;
  final location = (json['location'] as String?)?.trim();

  return Job(
    id: slug,
    title: title,
    company: company,
    location: (location == null || location.isEmpty)
        ? (remote ? 'Remote' : 'Location not specified')
        : location,
    type: _typeFromJobTypes(json['job_types']),
    workMode: remote ? WorkMode.remote : WorkMode.onsite,
    postedDaysAgo: _daysAgoFromUnix(json['created_at']),
    // Descriptions arrive as HTML — sometimes escaped HTML — and the detail
    // screen renders plain text.
    description: htmlToPlainText(
      json['description'] as String?,
      fallback: 'No description was provided for this listing.',
    ),
    responsibilities: const [],
    skills: _stringList(json['tags']),
    applyUrl: json['url'] as String?,
  );
}

JobType? _typeFromJobTypes(Object? value) {
  for (final raw in _stringList(value)) {
    switch (raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'fulltime':
      case 'permanent':
        return JobType.fullTime;
      case 'parttime':
        return JobType.partTime;
      case 'contract':
      case 'freelance':
        return JobType.contract;
      case 'internship':
      case 'intern':
        return JobType.internship;
    }
  }
  return null;
}

int _daysAgoFromUnix(Object? value) {
  if (value is! int) return 0;
  final posted = DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  final days = DateTime.now().toUtc().difference(posted).inDays;
  return days < 0 ? 0 : days;
}

List<String> _stringList(Object? value) {
  if (value is String) return value.isEmpty ? const [] : [value];
  if (value is List) {
    return value.whereType<String>().where((s) => s.isNotEmpty).toList();
  }
  return const [];
}
