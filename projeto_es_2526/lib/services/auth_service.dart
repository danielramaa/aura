import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/legal_document.dart';
import '../models/user_role.dart';
import '../utils/validators.dart';

class AuthService {
  static const _stayLoggedInKey = 'stay_logged_in';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> getStayLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_stayLoggedInKey) ?? true;
  }

  Future<void> setStayLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_stayLoggedInKey, value);
  }

  Future<UserCredential> login(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register(
    String email,
    String password, {
    required DateTime dateOfBirth,
    required bool acceptedTerms,
  }) async {
    // Acceptance and a verified minimum age are hard preconditions, enforced
    // here so they can't be bypassed by callers other than the registration
    // screen.
    if (!acceptedTerms) {
      throw ArgumentError(
        'Tem de aceitar os Termos e a Política de Privacidade para criar conta.',
      );
    }
    if (!isAtLeastMinimumAge(dateOfBirth)) {
      throw ArgumentError('Tem de ter pelo menos 13 anos para criar conta.');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      final userData = <String, Object?>{
        'role': UserRole.user.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
        'termsAccepted': true,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': LegalDocuments.termsVersion,
        'privacyPolicyVersion': LegalDocuments.privacyPolicyVersion,
        'dateOfBirth': Timestamp.fromDate(
          DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day),
        ),
        'ageVerifiedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(userData);
    } catch (_) {
      // Roll back the Auth account so there's no dangling user without a profile.
      await credential.user!.delete();
      rethrow;
    }
    return credential;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
