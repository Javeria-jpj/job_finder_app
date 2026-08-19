import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/data/resume_controller.dart';
import 'package:job_finder_app/data/resume_storage.dart';
import 'package:job_finder_app/models/resume_file.dart';
import 'package:job_finder_app/screens/profile/resume_screen.dart';
import 'package:job_finder_app/services/resume_picker.dart';
import 'package:job_finder_app/theme/app_theme.dart';
import 'package:provider/provider.dart';

ResumeFile file(String name, {int bytes = 1024}) => ResumeFile(
  name: name,
  contentType: ResumeFile.contentTypeFor(name) ?? 'application/octet-stream',
  bytes: Uint8List(bytes),
);

/// Stands in for Firestore.
class FakeResumeStorage implements ResumeStorage {
  final _controllers = <String, StreamController<ResumeFile?>>{};
  final saved = <ResumeFile>[];
  int removeCount = 0;

  bool failOnSave = false;

  StreamController<ResumeFile?> _controllerFor(String userId) => _controllers
      .putIfAbsent(userId, () => StreamController<ResumeFile?>.broadcast());

  void emit(String userId, ResumeFile? resume) =>
      _controllerFor(userId).add(resume);

  @override
  Stream<ResumeFile?> watch(String userId) => _controllerFor(userId).stream;

  @override
  Future<void> save(String userId, ResumeFile resume) async {
    if (failOnSave) throw StateError('offline');
    saved.add(resume);
  }

  @override
  Future<void> remove(String userId) async => removeCount++;
}

/// Stands in for the platform file dialogs.
class FakeResumePicker implements ResumePicker {
  FakeResumePicker({this.picks});

  /// What the dialog returns; null means the user cancelled.
  ResumeFile? picks;
  bool throwOnPick = false;
  bool saveSucceeds = true;
  final saved = <ResumeFile>[];

  @override
  Future<ResumeFile?> pick() async {
    if (throwOnPick) throw StateError('no picker');
    return picks;
  }

  @override
  Future<bool> save(ResumeFile resume) async {
    saved.add(resume);
    return saveSucceeds;
  }
}

void main() {
  group('ResumeFile', () {
    test('resolves the content type from the extension', () {
      expect(ResumeFile.contentTypeFor('cv.pdf'), 'application/pdf');
      expect(ResumeFile.contentTypeFor('CV.PDF'), 'application/pdf');
      expect(ResumeFile.contentTypeFor('cv.doc'), 'application/msword');
      expect(ResumeFile.contentTypeFor('cv.docx'), isNotNull);
    });

    test('rejects extensions it does not know', () {
      expect(ResumeFile.contentTypeFor('cv.txt'), isNull);
      expect(ResumeFile.contentTypeFor('cv.png'), isNull);
      expect(ResumeFile.contentTypeFor('cv'), isNull);
      expect(ResumeFile.contentTypeFor('cv.'), isNull);
    });

    test('reports a readable size', () {
      expect(file('cv.pdf', bytes: 512).sizeLabel, '512 B');
      expect(file('cv.pdf', bytes: 2048).sizeLabel, '2 KB');
      expect(file('cv.pdf', bytes: 2 * 1024 * 1024).sizeLabel, '2.0 MB');
    });
  });

  group('ResumeController', () {
    test('uploads the picked file', () async {
      final storage = FakeResumeStorage();
      final picker = FakeResumePicker(picks: file('ada-cv.pdf'));
      final controller = ResumeController(storage: storage, picker: picker)
        ..loadFor('user-1');

      expect(await controller.pickAndUpload(), isTrue);

      expect(storage.saved.single.name, 'ada-cv.pdf');
      expect(controller.resume?.name, 'ada-cv.pdf');
      expect(controller.error, isNull);
      expect(controller.busy, isFalse);
    });

    test('cancelling is not an error', () async {
      final storage = FakeResumeStorage();
      final picker = FakeResumePicker(picks: null);
      final controller = ResumeController(storage: storage, picker: picker)
        ..loadFor('user-1');

      expect(await controller.pickAndUpload(), isFalse);

      expect(storage.saved, isEmpty);
      expect(controller.error, isNull);
      expect(controller.busy, isFalse);
    });

    test('refuses a file that is not a PDF or Word document', () async {
      final storage = FakeResumeStorage();
      final picker = FakeResumePicker(picks: file('holiday.png'));
      final controller = ResumeController(storage: storage, picker: picker)
        ..loadFor('user-1');

      expect(await controller.pickAndUpload(), isFalse);

      expect(storage.saved, isEmpty);
      expect(controller.error, contains('PDF or Word'));
    });

    test('refuses a file over the document limit', () async {
      final storage = FakeResumeStorage();
      final picker = FakeResumePicker(
        picks: file('huge.pdf', bytes: ResumeFile.maxBytes + 1),
      );
      final controller = ResumeController(storage: storage, picker: picker)
        ..loadFor('user-1');

      expect(await controller.pickAndUpload(), isFalse);

      expect(storage.saved, isEmpty);
      expect(controller.error, contains('limit'));
    });

    test('refuses an empty file', () async {
      final picker = FakeResumePicker(picks: file('empty.pdf', bytes: 0));
      final controller = ResumeController(
        storage: FakeResumeStorage(),
        picker: picker,
      )..loadFor('user-1');

      expect(await controller.pickAndUpload(), isFalse);
      expect(controller.error, contains('empty'));
    });

    test('reports a failed upload without keeping the file', () async {
      final storage = FakeResumeStorage()..failOnSave = true;
      final picker = FakeResumePicker(picks: file('ada-cv.pdf'));
      final controller = ResumeController(storage: storage, picker: picker)
        ..loadFor('user-1');

      expect(await controller.pickAndUpload(), isFalse);

      expect(controller.resume, isNull);
      expect(controller.error, contains('Upload failed'));
      expect(controller.busy, isFalse, reason: 'the screen must not stay busy');
    });

    test('an unregistered plugin says to restart, not just "failed"', () {
      expect(
        ResumeController.pickerFailureMessage(
          MissingPluginException('no implementation found'),
        ),
        contains('run it again'),
      );
      expect(
        ResumeController.pickerFailureMessage(StateError('something else')),
        'Could not open the file picker.',
      );
    });

    test('a picker that throws does not leave the screen stuck', () async {
      final picker = FakeResumePicker()..throwOnPick = true;
      final controller = ResumeController(
        storage: FakeResumeStorage(),
        picker: picker,
      )..loadFor('user-1');

      expect(await controller.pickAndUpload(), isFalse);
      expect(controller.busy, isFalse);
      expect(controller.error, isNotNull);
    });

    test('a stored resume arrives from the cloud', () async {
      final storage = FakeResumeStorage();
      final controller = ResumeController(
        storage: storage,
        picker: FakeResumePicker(),
      )..loadFor('user-1');

      storage.emit('user-1', file('from-cloud.pdf'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.resume?.name, 'from-cloud.pdf');
      expect(controller.hasResume, isTrue);
    });

    test('removing deletes it from storage', () async {
      final storage = FakeResumeStorage();
      final picker = FakeResumePicker(picks: file('ada-cv.pdf'));
      final controller = ResumeController(storage: storage, picker: picker)
        ..loadFor('user-1');
      await controller.pickAndUpload();

      await controller.remove();

      expect(storage.removeCount, 1);
      expect(controller.resume, isNull);
    });

    test('switching account clears the previous resume', () async {
      final storage = FakeResumeStorage();
      final controller = ResumeController(
        storage: storage,
        picker: FakeResumePicker(),
      )..loadFor('user-1');

      storage.emit('user-1', file('ada-cv.pdf'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.resume, isNotNull);

      controller.loadFor('user-2');
      expect(controller.resume, isNull);
    });

    test('download hands the stored file to the picker', () async {
      final storage = FakeResumeStorage();
      final picker = FakeResumePicker(picks: file('ada-cv.pdf'));
      final controller = ResumeController(storage: storage, picker: picker)
        ..loadFor('user-1');
      await controller.pickAndUpload();

      expect(await controller.download(), isTrue);
      expect(picker.saved.single.name, 'ada-cv.pdf');
    });
  });

  group('ResumeScreen', () {
    Future<ResumeController> pump(
      WidgetTester tester, {
      required FakeResumePicker picker,
      FakeResumeStorage? storage,
    }) async {
      final controller = ResumeController(
        storage: storage ?? FakeResumeStorage(),
        picker: picker,
      )..loadFor('user-1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ResumeController>.value(
          value: controller,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ResumeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('offers an upload when there is no resume', (tester) async {
      await pump(tester, picker: FakeResumePicker());

      expect(find.text('Upload your resume'), findsOneWidget);
      expect(find.text('Choose file'), findsOneWidget);
      expect(find.text('Download'), findsNothing);
    });

    testWidgets('choosing a file shows it on the card', (tester) async {
      final picker = FakeResumePicker(picks: file('ada-cv.pdf', bytes: 2048));
      await pump(tester, picker: picker);

      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();

      expect(find.text('ada-cv.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('a rejected file is explained on screen', (tester) async {
      final picker = FakeResumePicker(picks: file('notes.txt'));
      await pump(tester, picker: picker);

      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a PDF or Word document.'), findsOneWidget);
      expect(find.text('Upload your resume'), findsOneWidget);
    });

    testWidgets('removing asks first', (tester) async {
      final storage = FakeResumeStorage();
      final controller = await pump(
        tester,
        picker: FakeResumePicker(),
        storage: storage,
      );

      storage.emit('user-1', file('ada-cv.pdf'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Remove resume?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(storage.removeCount, 0, reason: 'cancelling keeps the file');

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(storage.removeCount, 1);
      expect(controller.resume, isNull);
    });
  });
}
