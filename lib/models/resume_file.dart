import 'package:flutter/foundation.dart';

/// A resume document the user has uploaded, bytes and all.
@immutable
class ResumeFile {
  const ResumeFile({
    required this.name,
    required this.contentType,
    required this.bytes,
    this.updatedAt,
  });

  /// File name including the extension, e.g. `ada-lovelace-cv.pdf`.
  final String name;

  final String contentType;
  final Uint8List bytes;

  /// When it was stored. Null for a file that has not been saved yet.
  final DateTime? updatedAt;

  int get sizeBytes => bytes.length;

  /// A Firestore document caps out at 1 MiB including field names and
  /// overhead, so the payload is held below that with room to spare.
  static const int maxBytes = 900 * 1024;

  static const Map<String, String> contentTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  static List<String> get allowedExtensions => contentTypes.keys.toList();

  /// The MIME type for a file name, or null when the extension is not one of
  /// [contentTypes]. The picker filters by extension, but on some platforms
  /// the user can still switch it to "all files".
  static String? contentTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return null;
    return contentTypes[fileName.substring(dot + 1).toLowerCase()];
  }

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// "PDF", "DOC", "DOCX" — for the badge on the file card.
  String get extensionLabel {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'FILE';
    return name.substring(dot + 1).toUpperCase();
  }

  ResumeFile copyWith({DateTime? updatedAt}) => ResumeFile(
    name: name,
    contentType: contentType,
    bytes: bytes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
