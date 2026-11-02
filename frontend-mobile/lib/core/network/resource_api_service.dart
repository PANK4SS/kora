import 'package:dio/dio.dart';

import '../../models/document.dart';
import '../../models/user.dart';
import 'api_client.dart';
import 'offline_storage_service.dart';

class ResourceApiService {
  ResourceApiService._();

  static Future<List<Document>> getResources() async {
    final response = await ApiClient.instance.get<List<dynamic>>('/ressources');
    final data = response.data ?? <dynamic>[];

    return data
        .whereType<Map<String, dynamic>>()
        .map(Document.fromBackendResource)
        .toList();
  }

  static Future<Document> markAsDownloaded({
    required Document document,
    required User user,
  }) async {
    var offlineDocument = await OfflineStorageService.downloadDocument(
      document: document,
      userId: user.id,
      dio: ApiClient.instance,
    );

    try {
      await ApiClient.instance
          .patch<void>('/ressources/${document.id}/increment-download');
    } catch (_) {
      // L'incrément n'est pas bloquant pour la mise en offline côté mobile.
    }

    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/offline-downloads',
        data: {
          'resourceId': document.id,
          'userId': user.id,
        },
      );
      final recordId = (response.data?['_id'] ?? '').toString();
      if (recordId.isNotEmpty) {
        final updated = await OfflineStorageService.setOfflineRecordId(
          userId: user.id,
          documentId: document.id,
          offlineRecordId: recordId,
        );
        if (updated != null) {
          offlineDocument = updated;
        }
      }
    } catch (_) {
      // La synchro backend est secondaire par rapport au stockage local.
    }

    return offlineDocument;
  }

  static Future<List<Document>> getOfflineDocumentsForUser(
    String userId,
  ) async {
    return OfflineStorageService.getOfflineDocuments(userId);
  }

  static Future<void> removeOfflineRecord({
    required String userId,
    required Document document,
  }) async {
    await OfflineStorageService.removeOfflineDocument(
      userId: userId,
      document: document,
    );

    final offlineRecordId = document.offlineRecordId;
    if (offlineRecordId == null || offlineRecordId.isEmpty) {
      return;
    }

    try {
      await ApiClient.instance
          .delete<void>('/offline-downloads/$offlineRecordId');
    } catch (_) {
      // La suppression locale a déjà réussi.
    }
  }

  static Future<Set<String>> getOfflineDocumentIds(String userId) {
    return OfflineStorageService.getOfflineDocumentIds(userId);
  }

  static Future<void> openOfflineDocument(Document document) {
    return OfflineStorageService.openOfflineDocument(document);
  }

  static String parseError(Object error) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic>) {
        final message = payload['error'] ?? payload['message'];
        if (message != null) {
          return message.toString();
        }
      }
      return 'Erreur réseau (${error.response?.statusCode ?? 'connexion'}).';
    }

    return error.toString().replaceFirst('Exception: ', '');
  }
}
