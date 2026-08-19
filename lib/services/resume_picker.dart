import 'package:file_picker/file_picker.dart';

import '../models/resume_file.dart';

/// Opens the platform file dialogs.
///
/// Wrapped in an interface so screens and controllers can be tested without a
/// real picker, which needs a running platform to answer.
abstract class ResumePicker {
  /// Returns null when the user cancels.
  Future<ResumeFile?> pick();

  /// Hands the file back to the user — a download in the browser, a save
  /// dialog elsewhere. Returns false when cancelled.
  Future<bool> save(ResumeFile file);
}

class PlatformResumePicker implements ResumePicker {
  const PlatformResumePicker();

  @override
  Future<ResumeFile?> pick() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose your resume',
      type: FileType.custom,
      allowedExtensions: ResumeFile.allowedExtensions,
    );

    if (picked == null) return null;

    final bytes = await picked.readAsBytes();

    return ResumeFile(
      name: picked.name,
      // The dialog filters by extension, but "all files" is still reachable
      // on some platforms, so the type is resolved rather than assumed.
      contentType:
          ResumeFile.contentTypeFor(picked.name) ?? 'application/octet-stream',
      bytes: bytes,
    );
  }

  @override
  Future<bool> save(ResumeFile file) async {
    final location = await FilePicker.saveFile(
      fileName: file.name,
      bytes: file.bytes,
      mimeType: file.contentType,
    );
    return location != null;
  }
}
