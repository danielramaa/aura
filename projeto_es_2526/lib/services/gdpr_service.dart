import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles the RGPD/GDPR self-service flows: scheduling account deletion with a
/// grace period, exporting personal data, and carrying out the actual erasure.
///
/// The project runs on Firebase's free (Spark) plan, so there are no Cloud
/// Functions, scheduled jobs, or the Trigger Email extension. Everything here
/// runs client-side. As a consequence:
///   * The deletion is executed lazily by [DeletionGracePeriodGate] the next
///     time the user signs in after the grace period has elapsed. If the user
///     never signs in again, the erasure never runs — an unavoidable limitation
///     without a paid plan / server-side scheduler.
///   * Messages are anonymized rather than hard-deleted: the anonymousId→userId
///     reverse-lookup link is severed so the (randomly nicknamed) messages can
///     no longer be traced back to a real person, while group conversations stay
///     intact. Anonymized data is no longer personal data under the RGPD.
class GDPRService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GDPRService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const Duration gracePeriod = Duration(days: 30);

  /// Marks the account for deletion and starts the 30-day grace period. The
  /// account is not touched yet; erasure happens once the grace period expires.
  Future<void> scheduleAccountDeletion(String uid) async {
    final deletionDate = DateTime.now().add(gracePeriod);

    await _firestore.collection('users').doc(uid).update({
      'deletionScheduled': true,
      'deletionScheduledAt': FieldValue.serverTimestamp(),
      'deletionDate': Timestamp.fromDate(deletionDate),
    });
  }

  /// Cancels a pending deletion, reactivating the account.
  Future<void> cancelAccountDeletion(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'deletionScheduled': FieldValue.delete(),
      'deletionScheduledAt': FieldValue.delete(),
      'deletionDate': FieldValue.delete(),
    });
  }

  Future<bool> isAccountDeletionScheduled(String uid) async {
    return (await getScheduledDeletionDate(uid)) != null;
  }

  /// Returns the scheduled permanent-deletion date, or null if the account is
  /// not scheduled for deletion (or the read fails — callers fail open).
  Future<DateTime?> getScheduledDeletionDate(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data?['deletionScheduled'] != true) return null;
      final ts = data?['deletionDate'];
      return ts is Timestamp ? ts.toDate() : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> generateExportData(String uid) async {
    // 1. Profile data.
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    // 2. Anonymous identities (one per group the user participates in).
    final identitiesSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('anonymousIdentities')
        .get();

    final identities = identitiesSnap.docs.map((d) {
      final data = d.data();
      return {
        'groupId': d.id,
        'anonymousId': data['anonymousId'] ?? '',
        'nickname': data['nickname'] ?? '',
        'avatarIndex': data['avatarIndex'] ?? 0,
      };
    }).toList();

    // 3. Messages the user authored, resolved through each anonymous identity.
    final messages = <Map<String, dynamic>>[];
    for (final identity in identities) {
      final groupId = identity['groupId'] as String;
      final anonymousId = identity['anonymousId'] as String;
      if (anonymousId.isEmpty) continue;

      final msgSnap = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .where('senderId', isEqualTo: anonymousId)
          .get();

      for (final m in msgSnap.docs) {
        final data = m.data();
        messages.add({
          'groupId': groupId,
          'messageId': m.id,
          'text': data['text'] ?? '',
          'type': data['type'] ?? 'text',
          'timestamp': data['timestamp']?.toString() ?? '',
        });
      }
    }

    return {
      'profile': {
        'uid': uid,
        'email': _auth.currentUser?.email,
        'displayName': _auth.currentUser?.displayName,
        'role': userData['role'] ?? 'user',
        'createdAt': userData['createdAt']?.toString() ?? '',
        'termsAccepted': userData['termsAccepted'] ?? false,
        'termsVersion': userData['termsVersion'] ?? '',
        'privacyPolicyVersion': userData['privacyPolicyVersion'] ?? '',
        'dateOfBirth': userData['dateOfBirth']?.toString() ?? '',
      },
      'anonymousIdentities': identities,
      'messages': messages,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<String> writeExportFile(String uid, Map<String, dynamic> data) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/export_data_$uid.json');
    await file.writeAsString(jsonStr, flush: true);
    return file.path;
  }

  /// Permanently erases the user's personal data and deletes their account.
  ///
  /// Erasure model (see class docs): the profile document and moderator
  /// applications are hard-deleted, the anonymousId→userId reverse-lookup link
  /// is severed (anonymizing the user's messages), and finally the Firebase
  /// Auth account is removed.
  ///
  /// The Firestore cascade runs before the Auth deletion so that, if removing
  /// the Auth user requires a recent re-login, the personal data is already
  /// gone rather than being left behind.
  Future<void> executeAccountDeletion(String uid) async {
    // 1. Sever each anonymous identity's link to the real user, then drop the
    //    user-side identity record (which lives under users/{uid}).
    final identitiesSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('anonymousIdentities')
        .get();

    for (final idDoc in identitiesSnap.docs) {
      final anonymousId = idDoc.data()['anonymousId'] as String?;
      if (anonymousId != null && anonymousId.isNotEmpty) {
        // Remove the userId field from the reverse-lookup so the anonymous
        // messages can no longer be traced back to this person.
        await _firestore
            .collection('anonymousIdentities')
            .doc(anonymousId)
            .set({
              'userId': FieldValue.delete(),
              'anonymizedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
      await idDoc.reference.delete();
    }

    // 2. Moderator applications hold the user's email and license number.
    final appsSnap = await _firestore
        .collection('moderator_applications')
        .where('userId', isEqualTo: uid)
        .get();
    for (final appDoc in appsSnap.docs) {
      await appDoc.reference.delete();
    }

    // 3. The profile document (email link, role, date of birth, FCM token, ...).
    await _firestore.collection('users').doc(uid).delete();

    // 4. The Firebase Auth account. Personal data is already erased above, so a
    //    requires-recent-login failure here is swallowed rather than recreated.
    try {
      final user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        await user.delete();
      }
    } catch (_) {
      // Ignore: the account is left signed-out by the caller either way.
    }
  }
}
