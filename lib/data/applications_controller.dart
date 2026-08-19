import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/job.dart';
import '../models/job_application.dart';

/// Jobs the user has applied to, and how far each one has progressed.
///
/// Persisted to local storage, keyed per account. There is no employer-side
/// backend, so stages are advanced by the user from the tracker screen.
class ApplicationsController extends ChangeNotifier {
  ApplicationsController(this._prefs);

  final SharedPreferences _prefs;

  String? _userId;
  final Map<String, JobApplication> _applications = {};

  List<JobApplication> get applications {
    final list = _applications.values.toList()
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return List.unmodifiable(list);
  }

  int get count => _applications.length;

  int stageCount(ApplicationStage stage) =>
      _applications.values.where((a) => a.stage == stage).length;

  List<JobApplication> byStage(ApplicationStage stage) =>
      applications.where((a) => a.stage == stage).toList();

  bool hasApplied(String jobId) => _applications.containsKey(jobId);

  JobApplication? forJob(String jobId) => _applications[jobId];

  String get _storageKey => 'applications_${_userId ?? 'anonymous'}';

  void loadFor(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _applications
      ..clear()
      ..addAll(_read());
    notifyListeners();
  }

  /// Records an application. Returns false if the job was already applied to.
  bool apply(Job job) {
    if (_applications.containsKey(job.id)) return false;
    _applications[job.id] = JobApplication(
      job: job,
      stage: ApplicationStage.applied,
      appliedAt: DateTime.now(),
    );
    _write();
    notifyListeners();
    return true;
  }

  void setStage(String jobId, ApplicationStage stage, {String? note}) {
    final existing = _applications[jobId];
    if (existing == null) return;
    _applications[jobId] = existing.copyWith(stage: stage, note: note);
    _write();
    notifyListeners();
  }

  void withdraw(String jobId) {
    if (_applications.remove(jobId) == null) return;
    _write();
    notifyListeners();
  }

  Map<String, JobApplication> _read() {
    final raw = _prefs.getStringList(_storageKey);
    if (raw == null) return {};

    final result = <String, JobApplication>{};
    for (final entry in raw) {
      try {
        final application = JobApplication.fromJson(
          jsonDecode(entry) as Map<String, dynamic>,
        );
        result[application.job.id] = application;
      } catch (error) {
        // One unreadable entry must not discard the rest.
        debugPrint('Skipping unreadable application: $error');
      }
    }
    return result;
  }

  Future<void> _write() async {
    await _prefs.setStringList(
      _storageKey,
      _applications.values.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }
}
