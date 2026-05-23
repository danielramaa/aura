import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/anonymous_identity.dart';

abstract class ReportServiceInterface {
  Future<String?> submitUserReport({
    required String groupId,
    required String groupName,
    required AnonymousIdentity reporterIdentity,
    required String reportedAnonymousId,
    required String reportedNickname,
    required int reportedAvatarIndex,
    required String category,
    required String reason,
    required String description,
  });

  Future<String?> submitMessageReport({
    required String groupId,
    required String groupName,
    required AnonymousIdentity reporterIdentity,
    required String messageId,
    required String messageText,
    required String messageSenderAnonymousId,
    required String messageSenderNickname,
    required int messageSenderAvatarIndex,
    required String category,
    required String details,
  });
}

class ReportService implements ReportServiceInterface {
  static const int maxReasonLength = 200;
  static const int maxDescriptionLength = 2000;
  static const List<String> userReportCategories = [
    'Spam',
    'Harassment',
    'Misinformation',
    'Abuse',
    'Other',
  ];
  static const Map<String, String> userReportCategoryLabels = {
    'Spam': 'Spam',
    'Harassment': 'Assédio',
    'Misinformation': 'Desinformação',
    'Abuse': 'Abuso',
    'Other': 'Outro',
  };

  static String labelForCategory(String category) =>
      userReportCategoryLabels[category] ?? category;

  static const List<String> messageReportCategories = [
    'Spam',
    'Misinformation',
    'Bullying',
    'LifeRisk',
    'Other',
  ];
  static const Map<String, String> messageReportCategoryLabels = {
    'Spam': 'Spam',
    'Misinformation': 'Desinformação',
    'Bullying': 'Bullying',
    'LifeRisk': 'Risco de vida',
    'Other': 'Outro',
  };

  static String labelForMessageCategory(String category) =>
      messageReportCategoryLabels[category] ?? category;

  static String suggestedMessageCategory(String text) {
    final normalized = text.toLowerCase();
    const lifeRiskTerms = [
      'suicídio',
      'suicidio',
      'matar-me',
      'matar me',
      'morrer',
      'acabar com a vida',
      'auto-mutilação',
      'automutilação',
      'overdose',
    ];
    return lifeRiskTerms.any(normalized.contains) ? 'LifeRisk' : 'Spam';
  }

  final FirebaseFirestore _firestore;

  ReportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String?> submitUserReport({
    required String groupId,
    required String groupName,
    required AnonymousIdentity reporterIdentity,
    required String reportedAnonymousId,
    required String reportedNickname,
    required int reportedAvatarIndex,
    required String category,
    required String reason,
    required String description,
  }) async {
    final trimmedCategory = category.trim();
    final trimmedReason = reason.trim();
    final trimmedDescription = description.trim();

    if (!userReportCategories.contains(trimmedCategory)) {
      return 'Escolhe uma categoria válida.';
    }
    if (trimmedReason.isEmpty) {
      return 'Escreve um motivo.';
    }
    if (trimmedReason.length > maxReasonLength) {
      return 'O motivo não pode exceder $maxReasonLength caracteres.';
    }
    if (reportedAnonymousId.isEmpty) {
      return 'Não foi possível identificar o utilizador denunciado.';
    }
    if (reportedAnonymousId == reporterIdentity.anonymousId) {
      return 'Não podes denunciar-te a ti próprio.';
    }
    if (trimmedDescription.length > maxDescriptionLength) {
      return 'A descrição não pode exceder $maxDescriptionLength caracteres.';
    }

    try {
      final reportRef = _firestore.collection('user_reports').doc();
      final safeGroupName = groupName.trim().isEmpty ? 'Community' : groupName;
      final safeNickname = reportedNickname.trim().isEmpty
          ? 'Anonymous'
          : reportedNickname.trim();

      await reportRef.set({
        'groupId': groupId,
        'groupName': safeGroupName,
        'reportedAnonymousId': reportedAnonymousId,
        'reportedNickname': safeNickname,
        'reportedAvatarIndex': reportedAvatarIndex,
        'reporterAnonymousId': reporterIdentity.anonymousId,
        'category': trimmedCategory,
        'reason': trimmedReason,
        'description': trimmedDescription,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _createAdminNotification(
        type: 'user_report',
        reportId: reportRef.id,
        groupId: groupId,
        groupName: safeGroupName,
        description: 'Nova denúncia de utilizador em "$safeGroupName".',
      );
      return null;
    } on FirebaseException catch (e) {
      debugPrint('Failed to submit user report: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Não foi possível enviar a denúncia: permissões do Firestore em falta. Publica as regras atualizadas.';
      }
      return 'Não foi possível enviar a denúncia (${e.code}). Tenta novamente.';
    } catch (_) {
      return 'Não foi possível enviar a denúncia. Tenta novamente.';
    }
  }

  @override
  Future<String?> submitMessageReport({
    required String groupId,
    required String groupName,
    required AnonymousIdentity reporterIdentity,
    required String messageId,
    required String messageText,
    required String messageSenderAnonymousId,
    required String messageSenderNickname,
    required int messageSenderAvatarIndex,
    required String category,
    required String details,
  }) async {
    final trimmedCategory = category.trim();
    final trimmedDetails = details.trim();

    if (!messageReportCategories.contains(trimmedCategory)) {
      return 'Escolhe uma categoria válida.';
    }
    if (messageId.isEmpty) {
      return 'Não foi possível identificar a mensagem denunciada.';
    }
    if (messageSenderAnonymousId.isEmpty) {
      return 'Não foi possível identificar o autor da mensagem.';
    }
    if (trimmedDetails.length > maxDescriptionLength) {
      return 'Os detalhes não podem exceder $maxDescriptionLength caracteres.';
    }

    try {
      final reportRef = _firestore.collection('message_reports').doc();
      final safeGroupName = groupName.trim().isEmpty ? 'Comunidade' : groupName;
      final safeNickname = messageSenderNickname.trim().isEmpty
          ? 'Anónimo'
          : messageSenderNickname.trim();

      await reportRef.set({
        'groupId': groupId,
        'groupName': safeGroupName,
        'messageId': messageId,
        'messageText': messageText,
        'messageSenderAnonymousId': messageSenderAnonymousId,
        'messageSenderNickname': safeNickname,
        'messageSenderAvatarIndex': messageSenderAvatarIndex,
        'reporterAnonymousId': reporterIdentity.anonymousId,
        'category': trimmedCategory,
        'details': trimmedDetails,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _createAdminNotification(
        type: 'message_report',
        reportId: reportRef.id,
        groupId: groupId,
        groupName: safeGroupName,
        description: 'Nova denúncia de mensagem em "$safeGroupName".',
      );
      return null;
    } on FirebaseException catch (e) {
      debugPrint('Failed to submit message report: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        return 'Não foi possível enviar a denúncia: permissões do Firestore em falta. Publica as regras atualizadas.';
      }
      return 'Não foi possível enviar a denúncia (${e.code}). Tenta novamente.';
    } catch (_) {
      return 'Não foi possível enviar a denúncia. Tenta novamente.';
    }
  }

  Future<void> _createAdminNotification({
    required String type,
    required String reportId,
    required String groupId,
    required String groupName,
    required String description,
  }) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': type,
        'reportId': reportId,
        'groupId': groupId,
        'groupName': groupName,
        'description': description,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to create admin report notification: $e');
    }
  }
}
