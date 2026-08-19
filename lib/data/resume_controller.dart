import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

import '../models/resume_file.dart';
import '../services/resume_picker.dart';
import 'resume_storage.dart';

/// The signed-in user's resume: pick a file, store it, hand it back.
///
/// Unlike bookmarks and preferences there is no local mirror — a document is
/// too big to sit in shared_preferences, and it is not worth the complexity
/// for something opened rarely.
class ResumeController extends ChangeNotifier {
  ResumeController({ResumeStorage? storage, ResumePicker? picker})
    : _storage = storage,
      _picker = picker ?? const PlatformResumePicker();

  final ResumeStorage? _storage;
  final ResumePicker _picker;

  String? _userId;
  ResumeFile? _resume;

  StreamSubscription<ResumeFile?>? _subscription;
  bool _busy = false;
  String? _error;

  ResumeFile? get resume => _resume;

  bool get hasResume => _resume != null;

  /// True while a pick, upload or delete is in flight.
  bool get busy => _busy;

  /// User-facing reason the last action failed, or null.
  String? get error => _error;

  void loadFor(String? userId) {
    if (_userId == userId) return;

    _userId = userId;
    _subscription?.cancel();
    _subscription = null;
    _resume = null;
    _error = null;
    notifyListeners();

    final storage = _storage;
    if (userId == null || storage == null) return;

    _subscription = storage
        .watch(userId)
        .listen(
          (file) {
            _resume = file;
            _error = null;
            notifyListeners();
          },
          onError: (Object error) {
            debugPrint('Resume sync failed: $error');
            _error = 'Could not load your resume.';
            notifyListeners();
          },
        );
  }

  /// Opens the file dialog and stores what comes back.
  ///
  /// Returns true when a file was uploaded; false when the user cancelled or
  /// the file was rejected, in which case [error] says why.
  Future<bool> pickAndUpload() async {
    if (_busy) return false;

    _setBusy(true);

    ResumeFile? picked;
    try {
      picked = await _picker.pick();
    } catch (error) {
      debugPrint('Resume picker failed: $error');
      _fail(pickerFailureMessage(error));
      return false;
    }

    // Cancelled: not an error, so leave the screen as it was.
    if (picked == null) {
      _setBusy(false);
      return false;
    }

    final rejection = _reject(picked);
    if (rejection != null) {
      _fail(rejection);
      return false;
    }

    final storage = _storage;
    final userId = _userId;
    if (storage == null || userId == null) {
      // No account to attach it to; keep it for this session so the screen
      // still reflects what the user just chose.
      _resume = picked;
      _setBusy(false);
      return true;
    }

    try {
      await storage.save(userId, picked);
      // The snapshot listener will deliver the stored copy, but showing it
      // now avoids a blank moment on a slow connection.
      _resume = picked;
      _error = null;
    } catch (error) {
      debugPrint('Resume upload failed: $error');
      _fail('Upload failed. Check your connection and try again.');
      return false;
    }

    _setBusy(false);
    return true;
  }

  /// Turns a picker failure into something the user can act on.
  ///
  /// A plugin added after the app was compiled is not in the running build's
  /// plugin registrant, and the call fails at the platform boundary. Hot
  /// restart does not regenerate that registrant — only a fresh run does — so
  /// this case gets its own message rather than a generic "could not open".
  @visibleForTesting
  static String pickerFailureMessage(Object error) {
    if (error is MissingPluginException || error is UnimplementedError) {
      return 'The file picker is not part of this build. Stop the app and '
          'run it again, rather than hot restarting.';
    }
    return 'Could not open the file picker.';
  }

  /// Why the file cannot be stored, or null when it is fine.
  String? _reject(ResumeFile file) {
    if (ResumeFile.contentTypeFor(file.name) == null) {
      return 'Choose a PDF or Word document.';
    }
    if (file.sizeBytes == 0) {
      return 'That file is empty.';
    }
    if (file.sizeBytes > ResumeFile.maxBytes) {
      return 'That file is ${file.sizeLabel}. The limit is '
          '${ResumeFile.maxBytes ~/ 1024} KB.';
    }
    return null;
  }

  Future<void> remove() async {
    if (_busy || _resume == null) return;

    _setBusy(true);

    final storage = _storage;
    final userId = _userId;
    if (storage != null && userId != null) {
      try {
        await storage.remove(userId);
      } catch (error) {
        debugPrint('Resume delete failed: $error');
        _fail('Could not remove the file. Try again.');
        return;
      }
    }

    _resume = null;
    _setBusy(false);
  }

  /// Saves the stored resume back to the user's device.
  Future<bool> download() async {
    final file = _resume;
    if (file == null || _busy) return false;

    _setBusy(true);
    try {
      final saved = await _picker.save(file);
      _setBusy(false);
      return saved;
    } catch (error) {
      debugPrint('Resume download failed: $error');
      _fail('Could not save the file.');
      return false;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _busy = value;
    if (value) _error = null;
    notifyListeners();
  }

  void _fail(String message) {
    _busy = false;
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
