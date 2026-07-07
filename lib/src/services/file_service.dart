import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/topology.dart';

// Top-level functions for Isolate computation
Topology _parseTopologyBytes(Uint8List bytes) {
  final content = utf8.decode(bytes);
  final json = jsonDecode(content) as Map<String, dynamic>;
  return Topology.fromJson(json);
}

Topology _parseTopologyString(String content) {
  final json = jsonDecode(content) as Map<String, dynamic>;
  return Topology.fromJson(json);
}

/// Handles saving and loading topology files in JSON format (.firelink).
class FileService {
  FileService._();

  static const String _extension = 'firelink';

  /// Saves a topology to a JSON file chosen by the user.
  ///
  /// Uses FilePicker.platform.saveFile to let the user pick the directory and name.
  /// Returns the file path on success, or null on failure.
  static Future<String?> saveTopology(Topology topology) async {
    try {
      final sanitizedName = topology.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim();
      final defaultName =
          '${sanitizedName.isEmpty ? "topology" : sanitizedName}.$_extension';

      final jsonString = jsonEncode(topology.toJson());
      final isMobile = Platform.isAndroid || Platform.isIOS;
      final bytes = isMobile
          ? Uint8List.fromList(utf8.encode(jsonString))
          : null;

      final String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Project As...',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: [_extension, 'json'],
        bytes: bytes,
      );

      if (path != null) {
        // On desktop platforms, FilePicker only returns the path, so we write manually.
        if (!isMobile) {
          final file = File(path);
          await file.writeAsString(jsonString, flush: true);
        }
        return path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Loads a topology from a user-selected file.
  ///
  /// Opens a file picker dialog filtered to .firelink files.
  static Future<Topology?> loadTopologyFromPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // Use any to prevent Android from graying out .firelink files
        allowMultiple: false,
        withData: true, // Read bytes natively to avoid scoped storage issues
      );

      if (result == null || result.files.isEmpty) return null;

      final bytes = result.files.single.bytes;
      if (bytes != null) {
        return await compute(_parseTopologyBytes, bytes);
      } else {
        // Fallback to path if bytes are null (e.g. on Desktop where withData is false by default if not supported)
        final path = result.files.single.path;
        if (path == null) return null;
        return loadTopologyFromPath(path);
      }
    } catch (e) {
      return null;
    }
  }

  /// Loads a topology from a specific file path.
  static Future<Topology?> loadTopologyFromPath(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;

      final content = await file.readAsString();
      return await compute(_parseTopologyString, content);
    } catch (e) {
      return null;
    }
  }

  /// Lists all saved topology files in the app's documents directory.
  static Future<List<SavedTopologyInfo>> listSavedTopologies() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final firelinkDir = Directory('${dir.path}/Firelink');

      if (!firelinkDir.existsSync()) return [];

      final files = firelinkDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.$_extension'))
          .toList();

      final infos = <SavedTopologyInfo>[];

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          infos.add(
            SavedTopologyInfo(
              name: json['name'] as String? ?? 'Untitled',
              path: file.path,
              modifiedAt: file.lastModifiedSync(),
              deviceCount: (json['devices'] as List?)?.length ?? 0,
            ),
          );
        } catch (_) {
          // Skip corrupt files.
        }
      }

      // Sort by modification date (newest first).
      infos.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return infos;
    } catch (e) {
      return [];
    }
  }

  /// Deletes a saved topology file.
  static Future<bool> deleteTopology(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// Metadata about a saved topology file (for listing without full parsing).
class SavedTopologyInfo {
  final String name;
  final String path;
  final DateTime modifiedAt;
  final int deviceCount;

  const SavedTopologyInfo({
    required this.name,
    required this.path,
    required this.modifiedAt,
    required this.deviceCount,
  });
}
