import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import 'remote_path.dart';

/// One item in a remote directory listing.
class RemoteEntry {
  const RemoteEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modified,
  });

  final String name;

  /// Absolute remote path, so callers never have to re-join.
  final String path;
  final bool isDirectory;

  /// Null when the server did not report a size (common for directories).
  final int? size;
  final DateTime? modified;
}

/// Thrown for remote file operations that failed, with a message safe to show.
class SftpFailure implements Exception {
  const SftpFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// File transfer over an existing SSH connection.
///
/// Wraps dartssh2's SFTP client in the app's own types so presentation code
/// never imports the SSH library, matching how host-key and prompt handling are
/// kept at the boundary.
class SftpService {
  SftpService(this._sftp);

  final SftpClient _sftp;

  /// Lists [path], directories first then names, case-insensitively.
  ///
  /// `.` and `..` are dropped: navigation is done with the breadcrumb and the
  /// up button, so showing them as entries only invites confusion.
  Future<List<RemoteEntry>> list(String path) async {
    final dir = RemotePath.normalize(path);
    final names = await _guard(() => _sftp.listdir(dir), 'List $dir');
    final entries = <RemoteEntry>[];
    for (final n in names) {
      if (n.filename == '.' || n.filename == '..') continue;
      entries.add(
        RemoteEntry(
          name: n.filename,
          path: RemotePath.join(dir, n.filename),
          isDirectory: n.attr.isDirectory,
          size: n.attr.isDirectory ? null : n.attr.size,
          modified: n.attr.modifyTime == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(n.attr.modifyTime! * 1000),
        ),
      );
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  /// Reads [path] fully into memory.
  ///
  /// Callers must keep this for reasonably sized files — the whole content is
  /// buffered so it can be handed to the platform's save dialog in one piece.
  Future<Uint8List> readFile(String path) {
    return _guard(() async {
      final file = await _sftp.open(path);
      try {
        return await file.readBytes();
      } finally {
        await file.close();
      }
    }, 'Download ${RemotePath.basename(path)}');
  }

  /// Writes [data] to [path], replacing any existing file.
  Future<void> writeFile(String path, Uint8List data) {
    return _guard(() async {
      final file = await _sftp.open(
        path,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      try {
        await file.writeBytes(data);
      } finally {
        await file.close();
      }
    }, 'Upload ${RemotePath.basename(path)}');
  }

  Future<void> createDirectory(String path) =>
      _guard(() => _sftp.mkdir(path), 'Create ${RemotePath.basename(path)}');

  Future<void> rename(String from, String to) =>
      _guard(() => _sftp.rename(from, to), 'Rename ${RemotePath.basename(from)}');

  /// Deletes a file, or an *empty* directory.
  ///
  /// Recursive deletion is deliberately not offered: one mistaken tap could
  /// wipe a server directory tree, and there is no undo over SFTP.
  Future<void> delete(RemoteEntry entry) => _guard(
        () => entry.isDirectory
            ? _sftp.rmdir(entry.path)
            : _sftp.remove(entry.path),
        'Delete ${entry.name}',
      );

  /// Turns library errors into a message the UI can show as-is. Raw
  /// `SftpStatusError` text ("SftpStatusError(3, ...)") means nothing to a user.
  Future<T> _guard<T>(Future<T> Function() op, String what) async {
    try {
      return await op();
    } on SftpStatusError catch (e) {
      throw SftpFailure('$what failed: ${e.message}');
    } catch (e) {
      throw SftpFailure('$what failed: $e');
    }
  }
}
