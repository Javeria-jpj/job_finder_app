import 'package:flutter/foundation.dart';

import 'job.dart';

/// Where an application has reached. Mirrors the sections of the tracker
/// screen, and the progress bar on each card.
enum ApplicationStage {
  applied('Applied', 0),
  interviewing('Interviewing', 1),
  offer('Offer', 2);

  const ApplicationStage(this.label, this.step);

  final String label;

  /// 0-based position along the Applied → Interviewing → Offer track.
  final int step;

  double get progress => (step + 1) / ApplicationStage.values.length;

  static ApplicationStage fromName(Object? name) {
    for (final stage in ApplicationStage.values) {
      if (stage.name == name) return stage;
    }
    return ApplicationStage.applied;
  }
}

@immutable
class JobApplication {
  const JobApplication({
    required this.job,
    required this.stage,
    required this.appliedAt,
    this.note,
  });

  final Job job;
  final ApplicationStage stage;
  final DateTime appliedAt;

  /// Free-text detail, e.g. "Technical Round".
  final String? note;

  JobApplication copyWith({ApplicationStage? stage, String? note}) {
    return JobApplication(
      job: job,
      stage: stage ?? this.stage,
      appliedAt: appliedAt,
      note: note ?? this.note,
    );
  }

  String get appliedLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[appliedAt.month - 1]} ${appliedAt.day}';
  }

  Map<String, dynamic> toJson() => {
    'job': job.toJson(),
    'stage': stage.name,
    'appliedAt': appliedAt.toIso8601String(),
    'note': note,
  };

  factory JobApplication.fromJson(Map<String, dynamic> json) => JobApplication(
    job: Job.fromJson(json['job'] as Map<String, dynamic>),
    stage: ApplicationStage.fromName(json['stage']),
    appliedAt:
        DateTime.tryParse(json['appliedAt'] as String? ?? '') ?? DateTime.now(),
    note: json['note'] as String?,
  );
}
