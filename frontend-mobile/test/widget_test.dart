import 'package:flutter_test/flutter_test.dart';
import 'package:kora_mobile/models/document.dart';
import 'package:kora_mobile/models/user.dart';

void main() {
  group('User.fromJson', () {
    test('conserve universityId lors de la désérialisation', () {
      final user = User.fromJson({
        'id': 'u1',
        'name': 'Alice',
        'email': 'alice@kora.bf',
        'university': 'Université de Ouagadougou',
        'universityId': '507f1f77bcf86cd799439011',
      });

      expect(user.university, 'Université de Ouagadougou');
      expect(user.universityId, '507f1f77bcf86cd799439011');
    });

    test('interprète un ObjectId comme identifiant université', () {
      final user = User.fromJson({
        'id': 'u1',
        'name': 'Alice',
        'universite': '507f1f77bcf86cd799439011',
      });

      expect(user.universityId, '507f1f77bcf86cd799439011');
      expect(user.university, isEmpty);
    });
  });

  group('Document.fromJson', () {
    test('relit un document stocké hors ligne', () {
      final document = Document.fromJson({
        'id': 'd1',
        'title': "Cours d'analyse",
        'type': 'cours',
        'level': 'L1',
        'filiere': 'Mathématiques',
        'filePath': '/tmp/cours.pdf',
        'isDownloaded': true,
      });

      expect(document.id, 'd1');
      expect(document.title, "Cours d'analyse");
      expect(document.type, DocumentType.cours);
      expect(document.filePath, '/tmp/cours.pdf');
      expect(document.isDownloaded, isTrue);
    });
  });
}
