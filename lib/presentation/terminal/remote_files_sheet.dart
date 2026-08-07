import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/ssh/remote_path.dart';
import '../../data/ssh/sftp_service.dart';

/// Remote file browser for a connected session (SFTP over the same connection).
///
/// Opened full-screen rather than as a small sheet: browsing a filesystem needs
/// room, and on a phone a half-height list is unusable.
Future<void> showRemoteFiles(
  BuildContext context, {
  required SftpService sftp,
  required String title,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RemoteFilesPage(sftp: sftp, title: title),
      ),
    );

class _RemoteFilesPage extends StatefulWidget {
  const _RemoteFilesPage({required this.sftp, required this.title});

  final SftpService sftp;
  final String title;

  @override
  State<_RemoteFilesPage> createState() => _RemoteFilesPageState();
}

class _RemoteFilesPageState extends State<_RemoteFilesPage> {
  /// Servers almost always land the user in their home directory, and '.' is
  /// what SFTP resolves to it — better than guessing `/home/<user>`.
  String _path = '.';
  List<RemoteEntry>? _entries;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _open('.');
  }

  Future<void> _open(String path) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = await widget.sftp.list(path);
      if (!mounted) return;
      setState(() {
        // '.' resolves server-side; show where we actually are only once we
        // know a concrete path.
        _path = path == '.' ? '.' : RemotePath.normalize(path);
        _entries = entries;
      });
    } on SftpFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(RemoteEntry entry) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await widget.sftp.readFile(entry.path);
      final saved = await _saveLocally(entry.name, data);
      messenger.showSnackBar(
        SnackBar(content: Text(saved == null ? 'Save cancelled.' : 'Saved to $saved')),
      );
    } on SftpFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Writes [data] locally, returning where it went, or null if cancelled.
  ///
  /// Desktop gets a real save dialog; mobile has no such picker, so the file
  /// goes to the app's documents directory and the path is reported instead of
  /// silently disappearing.
  Future<String?> _saveLocally(String name, Uint8List data) async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    if (isDesktop) {
      final location = await getSaveLocation(suggestedName: name);
      if (location == null) return null;
      await XFile.fromData(data, name: name).saveTo(location.path);
      return location.path;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$name';
    await XFile.fromData(data, name: name).saveTo(path);
    return path;
  }

  Future<void> _upload() async {
    final picked = await openFile();
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await picked.readAsBytes();
      final target = RemotePath.join(_path, picked.name);
      await widget.sftp.writeFile(target, data);
      messenger.showSnackBar(SnackBar(content: Text('Uploaded ${picked.name}')));
      await _open(_path);
    } on SftpFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(RemoteEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${entry.name}"?'),
        content: Text(
          entry.isDirectory
              // rmdir only removes empty directories, and saying so up front
              // beats a cryptive "failure" afterwards.
              ? 'Only empty folders can be deleted. This cannot be undone.'
              : 'This deletes the file on the server. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.sftp.delete(entry);
      await _open(_path);
    } on SftpFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _rename(RemoteEntry entry) async {
    final name = await _askName('Rename', initial: entry.name);
    if (name == null || name == entry.name || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.sftp.rename(entry.path, RemotePath.join(_path, name));
      await _open(_path);
    } on SftpFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _newFolder() async {
    final name = await _askName('New folder');
    if (name == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.sftp.createDirectory(RemotePath.join(_path, name));
      await _open(_path);
    } on SftpFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<String?> _askName(String title, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((v) => (v == null || v.isEmpty) ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: AppBar(
        title: Text('Files · ${widget.title}'),
        actions: [
          IconButton(
            tooltip: 'New folder',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _busy ? null : _newFolder,
          ),
          IconButton(
            tooltip: 'Upload a file here',
            icon: const Icon(Icons.upload_file),
            onPressed: _busy ? null : _upload,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : () => _open(_path),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _PathBar(
            path: _path,
            onNavigate: _busy ? null : _open,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            MaterialBanner(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              leading: const Icon(Icons.error_outline),
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => _open(_path),
                  child: const Text('Try again'),
                ),
              ],
            ),
          Expanded(
            child: entries == null
                ? const SizedBox()
                : entries.isEmpty
                    ? const Center(child: Text('This folder is empty'))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          return ListTile(
                            leading: Icon(
                              e.isDirectory
                                  ? Icons.folder_outlined
                                  : Icons.insert_drive_file_outlined,
                            ),
                            title: Text(e.name),
                            subtitle: Text(_describe(e)),
                            onTap: _busy
                                ? null
                                : () => e.isDirectory
                                    ? _open(e.path)
                                    : _download(e),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'More actions',
                              onSelected: (v) {
                                switch (v) {
                                  case 'download':
                                    _download(e);
                                  case 'rename':
                                    _rename(e);
                                  case 'delete':
                                    _confirmDelete(e);
                                }
                              },
                              itemBuilder: (context) => [
                                if (!e.isDirectory)
                                  const PopupMenuItem(
                                    value: 'download',
                                    child: Text('Download'),
                                  ),
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _describe(RemoteEntry e) {
    if (e.isDirectory) return 'Folder';
    final parts = <String>[
      if (e.size != null) _formatSize(e.size!),
      if (e.modified != null) _formatDate(e.modified!),
    ];
    return parts.isEmpty ? 'File' : parts.join('  ·  ');
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// Breadcrumb bar. Every level is tappable, so getting back up does not mean
/// pressing "up" repeatedly.
class _PathBar extends StatelessWidget {
  const _PathBar({required this.path, required this.onNavigate});

  final String path;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    // Before the first listing resolves we only know '.', which has no
    // meaningful breadcrumb.
    if (path == '.') {
      return const SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Home'),
          ),
        ),
      );
    }
    final crumbs = RemotePath.breadcrumbs(path);
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Up one level',
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: onNavigate == null || path == RemotePath.root
                ? null
                : () => onNavigate!(RemotePath.parent(path)),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (final c in crumbs) ...[
                    TextButton(
                      onPressed:
                          onNavigate == null ? null : () => onNavigate!(c.path),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(c.name),
                    ),
                    if (c != crumbs.last)
                      const Icon(Icons.chevron_right, size: 14),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
