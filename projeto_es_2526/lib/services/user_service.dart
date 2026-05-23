import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_report.dart';
import '../models/moderator_application.dart';
import '../models/user_report.dart';
import '../models/user_role.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserRole> streamRole(String uid) => _userDoc(uid).snapshots().map(
    (snap) => UserRole.fromString(snap.data()?['role'] as String?),
  );

  Future<UserRole> getRole(String uid) async {
    final snap = await _userDoc(uid).get();
    return UserRole.fromString(snap.data()?['role'] as String?);
  }

  Stream<List<ModeratorApplication>> streamPendingApplications() {
    return _firestore
        .collection('moderator_applications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs.map(ModeratorApplication.fromFirestore).toList(),
        );
  }

  Stream<List<UserReport>> streamPendingUserReports() {
    return _firestore
        .collection('user_reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final reports = snap.docs.map(UserReport.fromFirestore).toList();
          reports.sort((a, b) {
            final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
          return reports;
        });
  }

  Stream<List<MessageReport>> streamPendingMessageReports() {
    return _firestore
        .collection('message_reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final reports = snap.docs.map(MessageReport.fromFirestore).toList();
          reports.sort((a, b) {
            final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return bTime.compareTo(aTime);
          });
          return reports;
        });
  }

  Future<String?> updateUserReportStatus(String reportId, String status) async {
    if (!['reviewed', 'dismissed'].contains(status)) {
      return 'Estado da denúncia inválido.';
    }

    try {
      await _firestore.collection('user_reports').doc(reportId).update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (_) {
      return 'Não foi possível atualizar a denúncia.';
    }
  }

  Future<String?> updateMessageReportStatus(
    String reportId,
    String status,
  ) async {
    if (!['reviewed', 'dismissed'].contains(status)) {
      return 'Estado da denúncia inválido.';
    }

    try {
      await _firestore.collection('message_reports').doc(reportId).update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (_) {
      return 'Não foi possível atualizar a denúncia.';
    }
  }

  Future<String?> approveApplication(String appId, String userId) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('moderator_applications').doc(appId), {
        'status': 'approved',
      });
      batch.update(_userDoc(userId), {'role': 'medic'});
      await batch.commit();
      return null;
    } catch (_) {
      return 'Failed to approve application.';
    }
  }

  Future<String?> denyApplication(String appId) async {
    try {
      await _firestore.collection('moderator_applications').doc(appId).update({
        'status': 'denied',
      });
      return null;
    } catch (_) {
      return 'Failed to deny application.';
    }
  }

  /// Revokes medic role and removes all medicAnonymousIds badge entries across
  /// every group the user belongs to, so the badge disappears immediately.
  Future<String?> revokeMedicRole(String userId) async {
    try {
      final identitiesSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('anonymousIdentities')
          .get();

      final batch = _firestore.batch();
      batch.update(_userDoc(userId), {'role': 'user'});

      for (final doc in identitiesSnap.docs) {
        final groupId = doc.id;
        final anonymousId = doc.data()['anonymousId'] as String?;
        if (anonymousId != null) {
          batch.delete(
            _firestore
                .collection('groups')
                .doc(groupId)
                .collection('medicAnonymousIds')
                .doc(anonymousId),
          );
        }
      }

      await batch.commit();
      return null;
    } catch (_) {
      return 'Failed to revoke medic role.';
    }
  }
}
