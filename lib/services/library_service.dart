import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/library_item.dart';

class LibraryService {
  final FirebaseFirestore _firestore;

  LibraryService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _libraryRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('library');

  Stream<List<LibraryItem>> watchLibrary(String uid) {
    return _libraryRef(uid).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => LibraryItem.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<LibraryItem> addToLibrary({
    required String uid,
    required String sourceId,
    required String type,
    required String source,
    int? pagesTotal,
    int? volumesTotal,
  }) async {
    final docId = LibraryItem.buildDocId(sourceId: sourceId, type: type);
    final item = LibraryItem(
      docId: docId,
      sourceId: sourceId,
      type: type,
      source: source,
      status: 'reading',
      addedAt: DateTime.now(),
      pagesTotal: pagesTotal,
      volumesTotal: volumesTotal,
    );
    await _libraryRef(uid).doc(docId).set(item.toMap());
    return item;
  }

  Future<void> updateBookProgress({required String uid, required String docId, required int pagesRead}) {
    return _libraryRef(uid).doc(docId).update({
      'pagesRead': pagesRead,
      'lastActivityAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateVolumeProgress({required String uid, required String docId, required int volumesRead}) {
    return _libraryRef(uid).doc(docId).update({
      'volumesRead': volumesRead,
      'lastActivityAt': DateTime.now().toIso8601String(),
    });
  }

  /// Records/unrecords a single volume as read, for manga's reading-history
  /// section — `volumeReadAt` entries drive that history the same way
  /// Showtime's `episodeWatchedAt` drives its watch history.
  Future<void> markVolumeRead({
    required String uid,
    required String docId,
    required int volume,
    required bool read,
  }) {
    final key = '$volume';
    return _libraryRef(uid).doc(docId).update({
      'volumeReadAt.$key': read ? DateTime.now().toIso8601String() : FieldValue.delete(),
      'lastActivityAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> setStatus({required String uid, required String docId, required String status}) {
    return _libraryRef(uid).doc(docId).update({'status': status});
  }

  Future<void> toggleFavorite({required String uid, required String docId, required bool favorite}) {
    return _libraryRef(uid).doc(docId).update({
      'favorite': favorite,
      'favoritedAt': favorite ? DateTime.now().toIso8601String() : null,
    });
  }

  Future<void> removeFromLibrary({required String uid, required String docId}) {
    return _libraryRef(uid).doc(docId).delete();
  }
}
