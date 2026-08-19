import 'package:flutter/foundation.dart';

/// Everything the user can set about themselves that is not owned by Firebase
/// Auth: job preferences and notification choices. The resume is a file, so
/// it lives in [ResumeController] rather than here.
///
/// Plain data, so it can be stored in local storage and in a Firestore
/// document without either one knowing about the other.
@immutable
class UserProfile {
  const UserProfile({
    this.desiredRole = '',
    this.location = '',
    this.industry = '',
    this.minSalary,
    this.remoteOnly = false,
    this.jobAlerts = true,
    this.applicationUpdates = true,
  });

  /// The role the user is aiming for, e.g. "Flutter Developer".
  final String desiredRole;

  final String location;
  final String industry;

  /// Expected minimum, in whatever currency the user thinks in. Null means
  /// "not stated" rather than zero.
  final int? minSalary;

  final bool remoteOnly;

  final bool jobAlerts;
  final bool applicationUpdates;

  static const UserProfile empty = UserProfile();

  /// True when the user has not filled anything in, so a local copy should
  /// never overwrite what is already in the cloud.
  bool get isEmpty =>
      desiredRole.isEmpty &&
      location.isEmpty &&
      industry.isEmpty &&
      minSalary == null &&
      !remoteOnly;

  /// Set when the preferences form has something in it, so the profile screen
  /// can say whether preferences are configured.
  bool get hasPreferences =>
      desiredRole.isNotEmpty ||
      location.isNotEmpty ||
      industry.isNotEmpty ||
      minSalary != null ||
      remoteOnly;

  UserProfile copyWith({
    String? desiredRole,
    String? location,
    String? industry,
    int? minSalary,
    bool clearMinSalary = false,
    bool? remoteOnly,
    bool? jobAlerts,
    bool? applicationUpdates,
  }) {
    return UserProfile(
      desiredRole: desiredRole ?? this.desiredRole,
      location: location ?? this.location,
      industry: industry ?? this.industry,
      // A null minSalary is a real value, so clearing it needs its own flag.
      minSalary: clearMinSalary ? null : (minSalary ?? this.minSalary),
      remoteOnly: remoteOnly ?? this.remoteOnly,
      jobAlerts: jobAlerts ?? this.jobAlerts,
      applicationUpdates: applicationUpdates ?? this.applicationUpdates,
    );
  }

  Map<String, dynamic> toJson() => {
    'desiredRole': desiredRole,
    'location': location,
    'industry': industry,
    'minSalary': minSalary,
    'remoteOnly': remoteOnly,
    'jobAlerts': jobAlerts,
    'applicationUpdates': applicationUpdates,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      desiredRole: _string(json['desiredRole']),
      location: _string(json['location']),
      industry: _string(json['industry']),
      minSalary: _int(json['minSalary']),
      remoteOnly: json['remoteOnly'] == true,
      // Notifications default to on, so a missing field must not read as off.
      jobAlerts: json['jobAlerts'] != false,
      applicationUpdates: json['applicationUpdates'] != false,
    );
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.desiredRole == desiredRole &&
      other.location == location &&
      other.industry == industry &&
      other.minSalary == minSalary &&
      other.remoteOnly == remoteOnly &&
      other.jobAlerts == jobAlerts &&
      other.applicationUpdates == applicationUpdates;

  @override
  int get hashCode => Object.hash(
    desiredRole,
    location,
    industry,
    minSalary,
    remoteOnly,
    jobAlerts,
    applicationUpdates,
  );
}
