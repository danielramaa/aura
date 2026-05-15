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
      final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists) {
        final roleStr = userDoc.data()?['role'] as String?;
        if (roleStr == 'medic') _userRole = UserRole.medic;
        else if (roleStr == 'admin') _userRole = UserRole.admin;
      }

      final identitiesSnap = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('anonymousIdentities')
          .get();

      if (_isDisposed) return;

      // whereIn is limited to 30 values; users in >30 groups see their first 30.
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
      _communityError = 'Failed to load communities.';
    } finally {
      if (!_isDisposed) {
        _isLoadingCommunities = false;
        notifyListeners();
      }
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

    if (passwordChanged && newPassword.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if ((emailChanged || passwordChanged) && currentPassword.isEmpty) {
      return 'Current password is required to change email or password.';
    }

    if ((emailChanged || passwordChanged) && currentUser!.email == null) {
      return 'Re-authentication is not supported for this account type.';
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

  Future<String?> submitModeratorApplication(String licenseNumber) async {
    if (currentUser == null) return 'Not logged in.';
    try {
      await _firestore.collection('moderator_applications').add({
        'userId': currentUser!.uid,
        'licenseNumber': licenseNumber,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Failed to submit application.';
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
        return 'Current password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'requires-recent-login':
        return 'Please sign in again before making this change.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
