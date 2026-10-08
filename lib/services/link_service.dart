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

  /// Yearly reading goals, keyed by year (2026 → 24). Kept on the profile
  /// doc rather than in local prefs so the goal follows the user between the
  /// APK and the web build. Years without a goal are simply absent.
  Stream<Map<int, int>> watchReadingGoals(String uid) {
    return _userDoc(uid).snapshots().map((snapshot) {
      final raw = snapshot.data()?['readingGoals'] as Map<String, dynamic>? ?? const {};
      final goals = <int, int>{};
      for (final entry in raw.entries) {
        final year = int.tryParse(entry.key);
        final value = entry.value;
        if (year != null && value is num) goals[year] = value.toInt();
      }
      return goals;
    });
  }

  /// Sets [year]'s goal, or clears it when [goal] is null.
  Future<void> setReadingGoal({required String uid, required int year, int? goal}) {
    return _userDoc(uid).set({
      'readingGoals': {'$year': goal ?? FieldValue.delete()},
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
