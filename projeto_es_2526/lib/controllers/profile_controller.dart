import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../models/user_role.dart';

class ProfileController extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  bool _isLoadingCommunities = false;
  bool get isLoadingCommunities => _isLoadingCommunities;

  UserRole _userRole = UserRole.user;
  UserRole get userRole => _userRole;

  String? _communityError;
  String? get communityError => _communityError;

  bool _isDisposed = false;

  List<Group> _joinedCommunities = const [];
  List<Group> get joinedCommunities => List.unmodifiable(_joinedCommunities);

  ProfileController({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance {
    _fetchUserCommunities();
  }

  Future<void> _fetchUserCommunities() async {
    if (currentUser == null) return;

    _isLoadingCommunities = true;
    _communityError = null;
    notifyListeners();

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (userDoc.exists) {
        _userRole = UserRole.fromString(userDoc.data()?['role'] as String?);
      }

      final identitiesSnap = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('anonymousIdentities')
          .get();

      if (_isDisposed) return;

      final groupIds = identitiesSnap.docs.map((d) => d.id).take(30).toList();

      if (groupIds.isEmpty) {
        _joinedCommunities = const [];
        return;
      }

      final groupsSnap = await _firestore
          .collection('groups')
          .where(FieldPath.documentId, whereIn: groupIds)
          .get();

      if (_isDisposed) return;

      _joinedCommunities = groupsSnap.docs.map(Group.fromFirestore).toList();
    } catch (_) {
      if (_isDisposed) return;
      _communityError = 'Falha ao carregar as comunidades.';
    } finally {
      if (!_isDisposed) {
        _isLoadingCommunities = false;
        notifyListeners();
      }
    }
  }


  Future<String?> updateProfile({
    required String displayName,
    required String photoURL,
    required String email,
    required String newPassword,
    required String currentPassword,
  }) async {
    if (currentUser == null) return 'Não está conectado.';

    final emailChanged = email.isNotEmpty && email != currentUser!.email;
    final passwordChanged = newPassword.isNotEmpty;

    if (passwordChanged && newPassword.length < 8) {
      return 'A password deve ter no mínimo 8 caracteres.';
    }

    if ((emailChanged || passwordChanged) && currentPassword.isEmpty) {
      return 'A password atual é necessária para alterar o e-mail ou a password.';
    }

    if ((emailChanged || passwordChanged) && currentUser!.email == null) {
      return 'A reautenticação não é suportada para este tipo de conta.';
    }

    try {
      if (emailChanged || passwordChanged) {
        final credential = EmailAuthProvider.credential(
          email: currentUser!.email!,
          password: currentPassword,
        );
        await currentUser!.reauthenticateWithCredential(credential);
      }

      await currentUser!.updateDisplayName(
        displayName.isEmpty ? null : displayName,
      );
      await currentUser!.updatePhotoURL(photoURL.isEmpty ? null : photoURL);

      if (emailChanged) await currentUser!.verifyBeforeUpdateEmail(email);
      if (passwordChanged) await currentUser!.updatePassword(newPassword);

      await currentUser!.reload();
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (_) {
      return 'Falha ao atualizar o perfil. Por favor, tente novamente.';
    }
  }

  Future<String?> submitModeratorApplication(String licenseNumber) async {
    if (currentUser == null) return 'Não está conectado.';
    try {
      final existing = await _firestore
          .collection('moderator_applications')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return 'Você já possui uma candidatura pendente.';
      }
      await _firestore.collection('moderator_applications').add({
        'userId': currentUser!.uid,
        'userEmail': currentUser!.email ?? '',
        'licenseNumber': licenseNumber,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'A candidatura não foi submetida.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  static String _authErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'A password está incorreta.';
      case 'email-already-in-use':
        return 'Este endereço de e-mail já está em uso.';
      case 'weak-password':
        return 'A password deve ter no mínimo 8 caracteres.';
      case 'requires-recent-login':
        return 'Por favor, faça login novamente antes de efetuar essa alteração.';
      case 'invalid-email':
        return 'Por favor, insira um endereço de e-mail válido.';
      default:
        return 'Ocorreu um erro. Por favor, tente novamente.';
    }
  }
}
