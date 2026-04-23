import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<String> _joinedCommunities = [];
  List<String> get joinedCommunities => _joinedCommunities;

  ProfileController() {
    _fetchUserCommunities();
  }

  Future<void> _fetchUserCommunities() async {
    if (currentUser == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      // Baseado no identity_service.dart, procuramos as identidades do utilizador
      // para saber a que comunidades (IDs) o utilizador se juntou.
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('anonymousIdentities')
          .get();

      _joinedCommunities = snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint("Erro ao carregar comunidades: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
    String? email,
    String? password,
  }) async {
    if (currentUser == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      if (displayName != null) await currentUser!.updateDisplayName(displayName);
      if (photoURL != null) await currentUser!.updatePhotoURL(photoURL);
      
      if (email != null && email.isNotEmpty && email != currentUser!.email) {
        await currentUser!.verifyBeforeUpdateEmail(email);
      }
      
      if (password != null && password.isNotEmpty) {
        await currentUser!.updatePassword(password);
      }
      await currentUser!.reload(); // Recarrega os dados do utilizador do Firebase
    } catch (e) {
      debugPrint("Erro ao atualizar perfil: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }
}