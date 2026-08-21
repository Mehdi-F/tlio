import 'package:cloud_firestore/cloud_firestore.dart';

/// TLIO is locked to exactly two people (see firestore.rules), so there's
/// no add/remove-friend flow to build — "my friend" is just whichever of
/// the two allowed emails isn't mine. Each user's profile doc gets
/// upserted on login (displayName/email/photoUrl), readable by either
/// allowed email; findOtherUser scans the (at most two-doc) users
/// collection for the one that isn't me.
class LinkService {
  final FirebaseFirestore _firestore;

  LinkService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _firestore.collection('users').doc(uid);

  Future<void> ensureProfile({required String uid, String? displayName, String? email, String? photoUrl}) {
    return _userDoc(uid).set({
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email.toLowerCase(),
      if (photoUrl != null) 'photoUrl': photoUrl,
    }, SetOptions(merge: true));
  }

  /// Returns the other allowed user's {uid, displayName, email, photoUrl},
  /// or null if they haven't opened the app yet.
  Future<Map<String, dynamic>?> findOtherUser(String myEmail) async {
    final snapshot = await _firestore.collection('users').get();
    for (final doc in snapshot.docs) {
      final email = doc.data()['email'] as String?;
      if (email != null && email.toLowerCase() != myEmail.trim().toLowerCase()) {
        return {...doc.data(), 'uid': doc.id};
      }
    }
    return null;
  }
}
