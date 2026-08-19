import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'user_profile_sync.dart';

/// The signed-in user's preferences, resume link and notification choices.
///
/// Same shape as [SavedJobsController]: local storage answers immediately,
/// Firestore is the source of truth once it responds.
class UserProfileController extends ChangeNotifier {
  UserProfileController(this._prefs, {UserProfileSync? sync}) : _sync = sync;

  final SharedPreferences _prefs;
  final UserProfileSync? _sync;

  String? _userId;
  UserProfile _profile = UserProfile.empty;

  StreamSubscription<UserProfile?>? _subscription;
  bool _mergedLocalIntoCloud = false;
  String? _syncError;

  UserProfile get profile => _profile;

  /// Set when the cloud write failed, so the UI can say it is local-only.
  String? get syncError => _syncError;

  String get _storageKey => 'user_profile_${_userId ?? 'anonymous'}';

  /// Points the controller at an account. Safe to call repeatedly.
  void loadFor(String? userId) {
    if (_userId == userId) return;

    _userId = userId;
    _subscription?.cancel();
    _subscription = null;
    _mergedLocalIntoCloud = false;
    _syncError = null;

    _profile = _read();
    notifyListeners();

    final sync = _sync;
    if (userId == null || sync == null) return;

    _subscription = sync
        .watch(userId)
        .listen(
          (remote) => _onRemoteChanged(userId, remote),
          onError: (Object error) {
            debugPrint('Profile sync failed: $error');
            _syncError = 'Preferences are saved on this device only.';
            notifyListeners();
          },
        );
  }

  Future<void> save(UserProfile profile) async {
    if (profile == _profile) return;

    _profile = profile;
    _syncError = null;
    notifyListeners();

    await _write();

    final sync = _sync;
    final userId = _userId;
    if (sync == null || userId == null) return;

    try {
      await sync.save(userId, profile);
    } catch (error) {
      debugPrint('Could not sync profile: $error');
      _syncError = 'Preferences are saved on this device only.';
      notifyListeners();
    }
  }

  void _onRemoteChanged(String userId, UserProfile? remote) {
    _syncError = null;

    // First snapshot for this account. If the cloud has nothing but this
    // device does, push it up instead of wiping what the user typed while
    // signed out.
    if (!_mergedLocalIntoCloud) {
      _mergedLocalIntoCloud = true;
      if (remote == null && !_profile.isEmpty) {
        _sync?.save(userId, _profile).catchError((Object error) {
          debugPrint('Could not upload local profile: $error');
        });
        notifyListeners();
        return;
      }
    }

    if (remote == null) return;

    _profile = remote;
    _write();
    notifyListeners();
  }

  UserProfile _read() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return UserProfile.empty;

    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      debugPrint('Skipping unreadable profile: $error');
      return UserProfile.empty;
    }
  }

  Future<void> _write() =>
      _prefs.setString(_storageKey, jsonEncode(_profile.toJson()));

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
