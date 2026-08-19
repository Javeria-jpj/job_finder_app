import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// Cloud copy of the user's profile, so preferences follow the account.
/// Behind an interface so the controller is testable without Firestore.
abstract class UserProfileSync {
  /// Emits the stored profile, or null when the account has none yet.
  Stream<UserProfile?> watch(String userId);

  Future<void> save(String userId, UserProfile profile);
}

/// Stores the profile as a map on the account document, `users/{uid}`.
///
/// A field on the existing user document rather than a new collection: there
/// is exactly one profile per account, so a collection would only ever hold
/// a single row.
class FirestoreUserProfileSync implements UserProfileSync {
  FirestoreUserProfileSync({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _field = 'profile';

  DocumentReference<Map<String, dynamic>> _document(String userId) =>
      _firestore.collection('users').doc(userId);

  @override
  Stream<UserProfile?> watch(String userId) {
    return _document(userId).snapshots().map((snapshot) {
      final data = snapshot.data();
      final profile = data?[_field];
      if (profile is! Map) return null;

      try {
        return UserProfile.fromJson(Map<String, dynamic>.from(profile));
      } catch (_) {
        // Written by a newer version of the app; ignore rather than crash.
        return null;
      }
    });
  }

  @override
  Future<void> save(String userId, UserProfile profile) {
    // Merge, so this never clobbers other fields on the account document.
    return _document(userId).set({
      _field: profile.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
