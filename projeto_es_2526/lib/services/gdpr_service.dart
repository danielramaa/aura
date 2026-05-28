import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown when account erasure cannot proceed because the user's sign-in is too
/// old: deleting the Firebase Auth account is a sensitive operation that needs a
/// recent login. Callers should prompt the user to sign in again and retry.
class RecentLoginRequiredException implements Exception {
  const RecentLoginRequiredException();
  @override
  String toString() =>
      'RecentLoginRequiredException: a recent sign-in is required to delete the account.';
}

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

  /// Auth account deletion needs a sign-in newer than this; otherwise Firebase
  /// rejects it with `requires-recent-login`.
  static const Duration _recentLoginWindow = Duration(minutes: 5);

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
  ///
  /// If the account is flagged for deletion but the stored date is missing or
  /// corrupt, we return a date one grace period out rather than null, so the
  /// gate shows the (recoverable) reactivation screen instead of silently
  /// ignoring a pending deletion.
  Future<DateTime?> getScheduledDeletionDate(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data?['deletionScheduled'] != true) return null;
      final ts = data?['deletionDate'];
      if (ts is Timestamp) return ts.toDate();
      return DateTime.now().add(gracePeriod);
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
    //    The per-group queries are independent, so run them in parallel.
    final messageLists = await Future.wait(
      identities.map((identity) async {
        final groupId = identity['groupId'] as String;
        final anonymousId = identity['anonymousId'] as String;
        if (anonymousId.isEmpty) return const <Map<String, dynamic>>[];

        final msgSnap = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('messages')
            .where('senderId', isEqualTo: anonymousId)
            .get();

        return msgSnap.docs.map((m) {
          final data = m.data();
          return {
            'groupId': groupId,
            'messageId': m.id,
            'text': data['text'] ?? '',
            'type': data['type'] ?? 'text',
            'timestamp': data['timestamp']?.toString() ?? '',
          };
        }).toList();
      }),
    );
    final messages = messageLists.expand((l) => l).toList();

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
  /// applications are hard-deleted, group artifacts (taken nickname/avatar
  /// slots, member count, medic badge) are cleaned up, the anonymousId→userId
  /// reverse-lookup link is severed (anonymizing the user's messages), and
  /// finally the Firebase Auth account is removed.
  ///
  /// Fail-safe ordering: we first confirm the Auth account can actually be
  /// removed (a recent sign-in). If it can't, we throw
  /// [RecentLoginRequiredException] *before* touching any data, so a stale
  /// session can never leave a half-deleted account behind.
  Future<void> executeAccountDeletion(String uid) async {
    final user = _auth.currentUser;

    // Pre-flight: abort early (no data touched) if the session is too old to
    // delete the Auth account.
    if (user != null && user.uid == uid) {
      final lastSignIn = user.metadata.lastSignInTime;
      if (lastSignIn != null &&
          DateTime.now().difference(lastSignIn) > _recentLoginWindow) {
        throw const RecentLoginRequiredException();
      }
    }

    final userSnap = await _firestore.collection('users').doc(uid).get();
    final isMedic = userSnap.data()?['role'] == 'medic';

    // 1. Per-group cleanup. Groups are independent, so process them in
    //    parallel; the steps *within* a group stay ordered.
    final identitiesSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('anonymousIdentities')
        .get();

    await Future.wait(
      identitiesSnap.docs.map((idDoc) => _eraseGroupIdentity(idDoc, isMedic)),
    );

    // 2. Moderator applications hold the user's email and license number.
    final appsSnap = await _firestore
        .collection('moderator_applications')
        .where('userId', isEqualTo: uid)
        .get();
    await Future.wait(appsSnap.docs.map((d) => d.reference.delete()));

    // 3. The profile document (email link, role, date of birth, FCM token, ...).
    await _firestore.collection('users').doc(uid).delete();

    // 4. The Firebase Auth account, last. Recency was pre-checked above, so this
    //    should succeed; the handling below covers the residual race where the
    //    session aged past the recent-login window mid-cascade.
    if (user != null && user.uid == uid) {
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // The delete failed, so we are still authenticated and can write.
          // Restore a minimal, non-personal deletion marker (all personal data
          // is already erased) with a past due-date, so the next *fresh* login
          // re-runs the now-idempotent cascade and re-attempts this delete —
          // rather than leaving an active Auth account with no profile.
          await _firestore.collection('users').doc(uid).set({
            'deletionScheduled': true,
            'deletionDate': Timestamp.fromDate(
              DateTime.now().subtract(const Duration(seconds: 1)),
            ),
          });
          throw const RecentLoginRequiredException();
        }
        // Other auth errors: personal data is already gone — best effort.
      } catch (_) {
        // Non-Firebase errors (e.g. test doubles): best effort.
      }
    }
  }

  /// Erases one group identity: severs the reverse-lookup link, removes the
  /// medic badge (medics only), frees the nickname/avatar slots, decrements the
  /// member count, and finally deletes the user-side identity record.
  ///
  /// The identity record is removed last because the medic-badge delete rule
  /// reads it to authorize the deletion.
  Future<void> _eraseGroupIdentity(
    QueryDocumentSnapshot<Map<String, dynamic>> idDoc,
    bool isMedic,
  ) async {
    final groupId = idDoc.id;
    final data = idDoc.data();
    final anonymousId = data['anonymousId'] as String?;
    final nickname = data['nickname'] as String?;
    final avatarIndex = data['avatarIndex'];
    final groupRef = _firestore.collection('groups').doc(groupId);

    if (anonymousId != null && anonymousId.isNotEmpty) {
      // Sever the anonymousId -> userId link so the anonymous messages can no
      // longer be traced back to this person.
      await _firestore.collection('anonymousIdentities').doc(anonymousId).set({
        'userId': FieldValue.delete(),
        'anonymizedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Remove the medic badge for this identity, if present. Only medics can
      // have one, and the delete rule requires the identity record (deleted
      // below) to still exist, so this must run first.
      if (isMedic) {
        final badgeRef = groupRef
            .collection('medicAnonymousIds')
            .doc(anonymousId);
        if ((await badgeRef.get()).exists) {
          await badgeRef.delete();
        }
      }
    }

    final batch = _firestore.batch();
    if (nickname != null) {
      batch.delete(groupRef.collection('takenNicknames').doc(nickname));
    }
    if (avatarIndex is int) {
      batch.delete(
        groupRef.collection('takenAvatarIndices').doc('$avatarIndex'),
      );
    }
    // Decrement memberCount only if the group has a Firestore document
    // (default/seeded groups don't).
    if ((await groupRef.get()).exists) {
      batch.update(groupRef, {'memberCount': FieldValue.increment(-1)});
    }
    batch.delete(idDoc.reference);
    await batch.commit();
  }
}
