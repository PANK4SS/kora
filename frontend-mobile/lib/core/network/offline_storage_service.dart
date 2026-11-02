import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/document.dart';

class OfflineStorageService {
  OfflineStorageService._();

  static const String _storageKeyPrefix = 'offline_documents_';

  static Future<Document> downloadDocument({
    required Document document,
    required String userId,
    required Dio dio,
  }) async {
    final sourceUrl = _normalizeSourceUrl(document.filePath, dio);
    if (sourceUrl == null) {
      throw Exception('URL du fichier introuvable pour ce document.');
    }

    final directory = await _ensureOfflineDirectory(userId);
    final extension = _resolveExtension(sourceUrl);
    final targetPath = '${directory.path}/${_safeFileName(document)}$extension';

    await dio.download(sourceUrl, targetPath);

    final file = File(targetPath);
    // ignore: avoid_slow_async_io
    final stat = await file.stat();

    final offlineDocument = document.copyWith(
      filePath: targetPath,
      isDownloaded: true,
      downloadedAt: DateTime.now(),
      fileSize: stat.size,
    );

    final documents = await getOfflineDocuments(userId);
    final updatedDocuments = documents
        .where((item) => item.id != document.id)
        .toList()
      ..add(offlineDocument);

    await _persistDocuments(userId, updatedDocuments);
    return offlineDocument;
  }

  static Future<List<Document>> getOfflineDocuments(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKeyPrefix + userId);
    if (raw == null || raw.isEmpty) {
      return <Document>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <Document>[];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Document.fromJson)
        .where((document) {
      final path = document.filePath;
      return path != null && path.isNotEmpty;
    }).toList();
  }

  static Future<Set<String>> getOfflineDocumentIds(String userId) async {
    final documents = await getOfflineDocuments(userId);
    return documents.map((item) => item.id).toSet();
  }

  /// Associe l'identifiant du suivi backend à un document déjà téléchargé.
  static Future<Document?> setOfflineRecordId({
    required String userId,
    required String documentId,
    required String offlineRecordId,
  }) async {
    final documents = await getOfflineDocuments(userId);
    var updated = false;

    final updatedDocuments = documents.map((document) {
      if (document.id != documentId) {
        return document;
      }
      updated = true;
      return document.copyWith(offlineRecordId: offlineRecordId);
    }).toList();

    if (!updated) {
      return null;
    }

    await _persistDocuments(userId, updatedDocuments);
    return updatedDocuments.firstWhere(
      (document) => document.id == documentId,
    );
  }

  static Future<void> removeOfflineDocument({
    required String userId,
    required Document document,
  }) async {
    final documents = await getOfflineDocuments(userId);

    final path = document.filePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      // ignore: avoid_slow_async_io
      if (await file.exists()) {
        await file.delete();
      }
    }

    final updatedDocuments =
        documents.where((item) => item.id != document.id).toList();
    await _persistDocuments(userId, updatedDocuments);
  }

  static Future<void> openOfflineDocument(Document document) async {
    final path = document.filePath;
    if (path == null || path.isEmpty) {
      throw Exception('Chemin local du fichier introuvable.');
    }

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  static Future<Directory> _ensureOfflineDirectory(String userId) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/offline/$userId');

    // ignore: avoid_slow_async_io
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  static Future<void> _persistDocuments(
    String userId,
    List<Document> documents,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = documents.map((item) => item.toJson()).toList();
    await prefs.setString(_storageKeyPrefix + userId, jsonEncode(payload));
  }

  static String _resolveExtension(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    final path = uri?.path ?? sourceUrl;
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) {
      return '.bin';
    }

    final extension = path.substring(lastDot);
    return extension.isEmpty ? '.bin' : extension;
  }

  static String _safeFileName(Document document) {
    final base = document.title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return '${base.isEmpty ? 'document' : base}_${document.id}';
  }

  static String? _normalizeSourceUrl(String? sourceUrl, Dio dio) {
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(sourceUrl);
    if (uri != null && uri.hasScheme) {
      return sourceUrl;
    }

    final baseUrl = dio.options.baseUrl.replaceFirst('/api', '');
    if (sourceUrl.startsWith('/')) {
      return '$baseUrl$sourceUrl';
    }

    return '$baseUrl/$sourceUrl';
  }
}
