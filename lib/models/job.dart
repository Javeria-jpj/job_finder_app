import 'package:flutter/foundation.dart';

enum JobType {
  fullTime('Full-time', 'FULL_TIME'),
  partTime('Part-time', 'PART_TIME'),
  contract('Contract', 'CONTRACTOR'),
  internship('Internship', 'INTERN');

  const JobType(this.label, this.apiValue);

  final String label;

  /// Value used by the `ai_employment_type` filter on Fantastic.jobs.
  final String apiValue;

  static JobType? fromApi(String? value) {
    if (value == null) return null;
    final normalized = value.toUpperCase();
    for (final type in JobType.values) {
      if (type.apiValue == normalized) return type;
    }
    // TEMPORARY, VOLUNTEER, PER_DIEM and OTHER have no tab of their own.
    return null;
  }
}

enum WorkMode {
  onsite('On-site'),
  hybrid('Hybrid'),
  remote('Remote');

  const WorkMode(this.label);

  final String label;

  static WorkMode? fromApi(String? value) {
    switch (value) {
      case 'Remote Solely':
      case 'Remote OK':
        return WorkMode.remote;
      case 'Hybrid':
        return WorkMode.hybrid;
      case 'On-site':
        return WorkMode.onsite;
      default:
        return null;
    }
  }
}

@immutable
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.postedDaysAgo,
    required this.description,
    required this.responsibilities,
    required this.skills,
    this.type,
    this.workMode,
    this.minSalary,
    this.maxSalary,
    this.salaryCurrency,
    this.salaryUnit,
    this.applyUrl,
    this.logoUrl,
  });

  final String id;
  final String title;
  final String company;
  final String location;

  /// Null when the source does not classify the listing.
  final JobType? type;
  final WorkMode? workMode;

  final double? minSalary;
  final double? maxSalary;
  final String? salaryCurrency;

  /// YEAR, MONTH, HOUR … as reported by the source.
  final String? salaryUnit;

  final int postedDaysAgo;
  final String description;
  final List<String> responsibilities;
  final List<String> skills;

  /// Where "Apply now" sends the user.
  final String? applyUrl;
  final String? logoUrl;

  /// Round-trips a saved job through local storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'company': company,
    'location': location,
    'type': type?.name,
    'workMode': workMode?.name,
    'minSalary': minSalary,
    'maxSalary': maxSalary,
    'salaryCurrency': salaryCurrency,
    'salaryUnit': salaryUnit,
    'postedDaysAgo': postedDaysAgo,
    'description': description,
    'responsibilities': responsibilities,
    'skills': skills,
    'applyUrl': applyUrl,
    'logoUrl': logoUrl,
  };

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'] as String,
    title: json['title'] as String,
    company: json['company'] as String,
    location: json['location'] as String,
    type: _enumByName(JobType.values, json['type']),
    workMode: _enumByName(WorkMode.values, json['workMode']),
    minSalary: (json['minSalary'] as num?)?.toDouble(),
    maxSalary: (json['maxSalary'] as num?)?.toDouble(),
    salaryCurrency: json['salaryCurrency'] as String?,
    salaryUnit: json['salaryUnit'] as String?,
    postedDaysAgo: json['postedDaysAgo'] as int? ?? 0,
    description: json['description'] as String? ?? '',
    responsibilities: List<String>.from(
      json['responsibilities'] as List? ?? [],
    ),
    skills: List<String>.from(json['skills'] as List? ?? []),
    applyUrl: json['applyUrl'] as String?,
    logoUrl: json['logoUrl'] as String?,
  );

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  /// Initials used when there is no logo image.
  String get companyInitials {
    final words = company.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
    }
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Null when the listing has no salary data, so the UI can hide the tag
  /// rather than show a misleading zero.
  String? get salaryRange {
    final min = minSalary;
    final max = maxSalary;
    if (min == null && max == null) return null;

    final currency = salaryCurrency ?? '';
    final unit = _unitSuffix;
    final amount = (min == null || max == null || min == max)
        ? _compact(max ?? min!)
        : '${_compact(min)} - ${_compact(max)}';

    return [
      amount,
      currency,
      unit,
    ].where((part) => part.isNotEmpty).join(' ').trim();
  }

  String get _unitSuffix {
    switch (salaryUnit?.toUpperCase()) {
      case 'YEAR':
        return '/ year';
      case 'MONTH':
        return '/ month';
      case 'WEEK':
        return '/ week';
      case 'DAY':
        return '/ day';
      case 'HOUR':
        return '/ hour';
      default:
        return '';
    }
  }

  String get postedLabel {
    if (postedDaysAgo <= 0) return 'Today';
    if (postedDaysAgo == 1) return 'Yesterday';
    if (postedDaysAgo < 7) return '$postedDaysAgo days ago';
    final weeks = postedDaysAgo ~/ 7;
    if (weeks < 5) return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    final months = postedDaysAgo ~/ 30;
    return months <= 1 ? '1 month ago' : '$months months ago';
  }

  static String _compact(double amount) {
    if (amount >= 1000000) {
      return '${_trim(amount / 1000000)}M';
    }
    if (amount >= 1000) {
      return '${_trim(amount / 1000)}k';
    }
    return _trim(amount);
  }

  static String _trim(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }
}
