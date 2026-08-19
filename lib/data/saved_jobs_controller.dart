import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/job.dart';
import 'saved_jobs_sync.dart';

/// Bookmarked jobs.
///
/// Firestore is the source of truth when someone is signed in, so bookmarks
/// follow the account across devices. Local storage mirrors it, so the Saved
/// tab opens instantly and still works offline.
class SavedJobsController extends ChangeNotifier {
  SavedJobsController(this._prefs, {SavedJobsSync? sync}) : _sync = sync;

  final SharedPreferences _prefs;
  final SavedJobsSync? _sync;

  /// Bookmarks are per account; signing in as someone else loads their set.
  String? _userId;

  final Map<String, Job> _saved = {};

  StreamSubscription<List<Job>>? _subscription;
  bool _mergedLocalIntoCloud = false;

  /// Set when cloud sync fails, so the UI can say bookmarks are local-only.
  String? _syncError;

  List<Job> get savedJobs => List.unmodifiable(_saved.values);

  int get count => _saved.length;

  bool isSaved(String jobId) => _saved.containsKey(jobId);

  String? get syncError => _syncError;

  String get _storageKey => 'saved_jobs_${_userId ?? 'anonymous'}';

  /// Points the controller at a user's bookmarks. Safe to call repeatedly;
  /// it only reloads when the user actually changed.
  void loadFor(String? userId) {
    if (_userId == userId) return;

    _userId = userId;
    _subscription?.cancel();
    _subscription = null;
    _mergedLocalIntoCloud = false;
    _syncError = null;

    // Show the cached copy straight away, then let the cloud correct it.
    _saved
      ..clear()
      ..addAll(_read());
    notifyListeners();

    final sync = _sync;
    if (userId == null || sync == null) return;

    _subscription = sync
        .watch(userId)
        .listen(
          (remote) => _onRemoteChanged(userId, remote),
          onError: (Object error) {
            debugPrint('Saved jobs sync failed: $error');
            _syncError = 'Bookmarks are saved on this device only.';
            notifyListeners();
          },
        );
  }

  /// Returns true if the job ended up saved.
  bool toggle(Job job) {
    final nowSaved = _saved.remove(job.id) == null;
    if (nowSaved) _saved[job.id] = job;

    _write();
    notifyListeners();

    final sync = _sync;
    final userId = _userId;
    if (sync != null && userId != null) {
      // Fire and forget: the local copy already reflects the change, and the
      // snapshot listener will reconcile if the write fails.
      final future = nowSaved
          ? sync.save(userId, job)
          : sync.remove(userId, job.id);
      future.catchError((Object error) {
        debugPrint('Could not sync bookmark: $error');
        _syncError = 'Bookmarks are saved on this device only.';
        notifyListeners();
      });
    }

    return nowSaved;
  }

  void _onRemoteChanged(String userId, List<Job> remote) {
    _syncError = null;

    final incoming = {for (final job in remote) job.id: job};

    // First snapshot for this account: push anything bookmarked before the
    // user signed in (or while offline) instead of letting the cloud erase it.
    if (!_mergedLocalIntoCloud) {
      _mergedLocalIntoCloud = true;
      final sync = _sync;
      final localOnly = _saved.values
          .where((job) => !incoming.containsKey(job.id))
          .toList();

      if (sync != null) {
        for (final job in localOnly) {
          sync.save(userId, job).catchError((Object error) {
            debugPrint('Could not upload local bookmark: $error');
          });
        }
      }
      for (final job in localOnly) {
        incoming[job.id] = job;
      }
    }

    _saved
      ..clear()
      ..addAll(incoming);
    _write();
    notifyListeners();
  }

  Map<String, Job> _read() {
    final raw = _prefs.getStringList(_storageKey);
    if (raw == null) return {};

    final jobs = <String, Job>{};
    for (final entry in raw) {
      try {
        final job = Job.fromJson(jsonDecode(entry) as Map<String, dynamic>);
        jobs[job.id] = job;
      } catch (error) {
        // A single corrupt entry must not wipe out the rest.
        debugPrint('Skipping unreadable saved job: $error');
      }
    }
    return jobs;
  }

  Future<void> _write() async {
    await _prefs.setStringList(
      _storageKey,
      _saved.values.map((job) => jsonEncode(job.toJson())).toList(),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
