import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/resume_file.dart';

/// Where an uploaded resume lives.
///
/// Behind an interface so the controller is testable, and so the backing
/// store can be swapped without touching anything above it.
abstract class ResumeStorage {
  Stream<ResumeFile?> watch(String userId);

  Future<void> save(String userId, ResumeFile file);

  Future<void> remove(String userId);
}

/// Stores the document at `users/{uid}/files/resume`, bytes included.
///
/// Firestore rather than Firebase Storage: Storage needs the paid Blaze plan,
/// and a resume comfortably fits in a Firestore document. The bytes go in as
/// a [Blob], which stores them raw — base64 in a string field would cost an
/// extra third in size for nothing.
///
/// The trade-off is the 1 MiB document limit, enforced as
/// [ResumeFile.maxBytes]. Swapping in a Storage-backed implementation later
/// means writing one more class, not changing the app.
class FirestoreResumeStorage implements ResumeStorage {
  FirestoreResumeStorage({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// One resume per account, so the document id is fixed.
  static const String _documentId = 'resume';

  DocumentReference<Map<String, dynamic>> _document(String userId) => _firestore
      .collection('users')
      .doc(userId)
      .collection('files')
      .doc(_documentId);

  @override
  Stream<ResumeFile?> watch(String userId) {
    return _document(userId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;

      final blob = data['data'];
      final name = data['name'];
      if (blob is! Blob || name is! String) return null;

      final updatedAt = data['updatedAt'];

      return ResumeFile(
        name: name,
        contentType:
            data['contentType'] as String? ?? 'application/octet-stream',
        bytes: blob.bytes,
        updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
      );
    });
  }

  @override
  Future<void> save(String userId, ResumeFile file) {
    return _document(userId).set({
      'name': file.name,
      'contentType': file.contentType,
      'size': file.sizeBytes,
      'data': Blob(file.bytes),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> remove(String userId) => _document(userId).delete();
}
