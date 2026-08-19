import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/data/user_profile_controller.dart';
import 'package:job_finder_app/data/user_profile_sync.dart';
import 'package:job_finder_app/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for Firestore.
class FakeProfileSync implements UserProfileSync {
  final _controllers = <String, StreamController<UserProfile?>>{};
  final saved = <UserProfile>[];

  bool failOnSave = false;

  StreamController<UserProfile?> _controllerFor(String userId) => _controllers
      .putIfAbsent(userId, () => StreamController<UserProfile?>.broadcast());

  /// Pushes what the cloud currently holds.
  void emit(String userId, UserProfile? profile) =>
      _controllerFor(userId).add(profile);

  @override
  Stream<UserProfile?> watch(String userId) => _controllerFor(userId).stream;

  @override
  Future<void> save(String userId, UserProfile profile) async {
    if (failOnSave) throw StateError('offline');
    saved.add(profile);
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('round-trips through JSON', () {
    const profile = UserProfile(
      desiredRole: 'Flutter Developer',
      location: 'Lahore',
      industry: 'Engineering',
      minSalary: 150000,
      remoteOnly: true,
      jobAlerts: false,
      applicationUpdates: true,
    );

    expect(UserProfile.fromJson(profile.toJson()), profile);
  });

  test('missing notification fields default to on', () {
    final profile = UserProfile.fromJson(const {'desiredRole': 'Designer'});

    expect(profile.jobAlerts, isTrue);
    expect(profile.applicationUpdates, isTrue);
    expect(profile.minSalary, isNull);
  });

  test('clearing the salary is distinct from leaving it alone', () {
    const profile = UserProfile(minSalary: 100);

    expect(profile.copyWith(location: 'Lahore').minSalary, 100);
    expect(profile.copyWith(clearMinSalary: true).minSalary, isNull);
  });

  test('saving keeps a local copy for the next launch', () async {
    final controller = UserProfileController(prefs)..loadFor('user-1');
    await controller.save(const UserProfile(desiredRole: 'Flutter Developer'));

    final reopened = UserProfileController(prefs)..loadFor('user-1');
    expect(reopened.profile.desiredRole, 'Flutter Developer');
  });

  test('profiles are per account', () async {
    final controller = UserProfileController(prefs)..loadFor('user-1');
    await controller.save(const UserProfile(desiredRole: 'Designer'));

    controller.loadFor('user-2');
    expect(controller.profile, UserProfile.empty);

    controller.loadFor('user-1');
    expect(controller.profile.desiredRole, 'Designer');
  });

  test('a cloud profile replaces the local copy', () async {
    final sync = FakeProfileSync();
    final controller = UserProfileController(prefs, sync: sync)
      ..loadFor('user-1');

    sync.emit('user-1', const UserProfile(desiredRole: 'Data Scientist'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.profile.desiredRole, 'Data Scientist');
  });

  test('a local profile is uploaded when the cloud has none', () async {
    // Set up as if the user filled the form in before this device synced.
    final seed = UserProfileController(prefs)..loadFor('user-1');
    await seed.save(const UserProfile(desiredRole: 'Engineer'));

    final sync = FakeProfileSync();
    final controller = UserProfileController(prefs, sync: sync)
      ..loadFor('user-1');

    sync.emit('user-1', null);
    await Future<void>.delayed(Duration.zero);

    expect(sync.saved.single.desiredRole, 'Engineer');
    expect(
      controller.profile.desiredRole,
      'Engineer',
      reason: 'an empty cloud must not wipe what the user typed',
    );
  });

  test('a failed upload is reported but kept locally', () async {
    final sync = FakeProfileSync()..failOnSave = true;
    final controller = UserProfileController(prefs, sync: sync)
      ..loadFor('user-1');

    await controller.save(const UserProfile(desiredRole: 'Engineer'));

    expect(controller.profile.desiredRole, 'Engineer');
    expect(controller.syncError, isNotNull);
  });
}
