import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/group.dart';

class ProfileController extends ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;

  bool _isLoadingCommunities = false;
  bool get isLoadingCommunities => _isLoadingCommunities;

  String? _communityError;
  String? get communityError => _communityError;

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
      final identitiesSnap = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('anonymousIdentities')
          .get();

      final groupDocs = await Future.wait(
        identitiesSnap.docs.map(
          (doc) => _firestore.collection('groups').doc(doc.id).get(),
        ),
      );

      _joinedCommunities = groupDocs
          .where((doc) => doc.exists)
          .map(Group.fromFirestore)
          .toList();
    } catch (_) {
      _communityError = 'Failed to load communities.';
    } finally {
      _isLoadingCommunities = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or a human-readable error message on failure.
  /// Re-authenticates when email or password are being changed.
  Future<String?> updateProfile({
    required String displayName,
    required String photoURL,
    required String email,
    required String newPassword,
    required String currentPassword,
  }) async {
    if (currentUser == null) return 'Not logged in.';

    final emailChanged = email.isNotEmpty && email != currentUser!.email;
    final passwordChanged = newPassword.isNotEmpty;

    if ((emailChanged || passwordChanged) && currentPassword.isEmpty) {
      return 'Current password is required to change email or password.';
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
      return 'Failed to update profile. Please try again.';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    notifyListeners();
  }

  static String _authErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'requires-recent-login':
        return 'Please sign in again before making this change.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
