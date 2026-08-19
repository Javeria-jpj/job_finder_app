import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/job.dart';

/// Cloud copy of a user's bookmarks, so they follow the account across
/// devices. Kept behind an interface so the controller can be tested without
/// a live Firestore.
abstract class SavedJobsSync {
  /// Emits the user's saved jobs whenever they change, from any device.
  Stream<List<Job>> watch(String userId);

  Future<void> save(String userId, Job job);

  Future<void> remove(String userId, String jobId);
}

/// Stores each bookmark at `users/{uid}/saved_jobs/{jobId}`.
class FirestoreSavedJobsSync implements SavedJobsSync {
  FirestoreSavedJobsSync({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('saved_jobs');

  @override
  Stream<List<Job>> watch(String userId) {
    return _collection(userId).snapshots().map((snapshot) {
      final jobs = <Job>[];
      for (final doc in snapshot.docs) {
        try {
          jobs.add(Job.fromJson(doc.data()));
        } catch (_) {
          // Ignore documents this version of the app cannot read.
        }
      }
      return jobs;
    });
  }

  @override
  Future<void> save(String userId, Job job) => _collection(userId)
      .doc(_documentId(job.id))
      .set({...job.toJson(), 'savedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> remove(String userId, String jobId) =>
      _collection(userId).doc(_documentId(jobId)).delete();

  /// Firestore document ids cannot contain slashes; job ids are slugs or
  /// numbers, but sanitise anyway so a stray id cannot throw.
  static String _documentId(String jobId) => jobId.replaceAll('/', '_');
}
