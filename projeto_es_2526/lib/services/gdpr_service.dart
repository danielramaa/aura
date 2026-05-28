import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GDPRService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GDPRService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<void> scheduleAccountDeletion(String uid, String email) async {
    final now = DateTime.now();
    final deletionDate = now.add(const Duration(days: 30));

    // 1. Update user document to set deletion scheduling
    await _firestore.collection('users').doc(uid).update({
      'deletionScheduled': true,
      'deletionScheduledAt': FieldValue.serverTimestamp(),
      'deletionDate': Timestamp.fromDate(deletionDate),
    });

    // 2. Add an email job to send confirmation email
    final dayStr = deletionDate.day.toString().padLeft(2, '0');
    final monthStr = deletionDate.month.toString().padLeft(2, '0');
    final dateFormatted = '$dayStr/$monthStr/${deletionDate.year}';

    await _firestore.collection('mail').add({
      'to': email,
      'message': {
        'subject': 'Confirmação de Eliminação de Conta (Período de Carência)',
        'text': 'A sua conta foi agendada para eliminação definitiva em $dateFormatted. Tem 30 dias de período de carência para cancelar este processo ao iniciar sessão na aplicação.',
      },
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelAccountDeletion(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'deletionScheduled': FieldValue.delete(),
      'deletionScheduledAt': FieldValue.delete(),
      'deletionDate': FieldValue.delete(),
    });
  }

  Future<bool> isAccountDeletionScheduled(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      return doc.data()?['deletionScheduled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> generateExportData(String uid) async {
    // 1. Get profile data
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    // 2. Get anonymous identities
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

  Future<void> sendExportConfirmationEmail(String email, String downloadLink) async {
    await _firestore.collection('mail').add({
      'to': email,
      'message': {
        'subject': 'Exportação de Dados Pronta - RGPD',
        'text': 'Os seus dados pessoais foram exportados com sucesso. Pode transferi-los usando o seguinte link temporário: $downloadLink',
      },
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
