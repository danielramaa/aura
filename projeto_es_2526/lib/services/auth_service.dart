import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/legal_document.dart';
import '../models/user_role.dart';

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
    DateTime? dateOfBirth,
    bool acceptedTerms = false,
  }) async {
    if (dateOfBirth != null && !_isAtLeast13(dateOfBirth)) {
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
        'termsAccepted': acceptedTerms,
      };

      if (dateOfBirth != null) {
        userData.addAll({
          'dateOfBirth': Timestamp.fromDate(
            DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day),
          ),
          'ageVerifiedAt': FieldValue.serverTimestamp(),
        });
      }

      if (acceptedTerms) {
        userData.addAll({
          'termsAcceptedAt': FieldValue.serverTimestamp(),
          'termsVersion': LegalDocuments.termsVersion,
          'privacyPolicyVersion': LegalDocuments.privacyPolicyVersion,
        });
      }

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(userData);
    } catch (_) {
      await credential.user!.delete();
      rethrow;
    }
    return credential;
  }

  bool _isAtLeast13(DateTime dateOfBirth) {
    final today = DateTime.now();
    final minimumDateOfBirth = DateTime(
      today.year - 13,
      today.month,
      today.day,
    );
    final normalizedDateOfBirth = DateTime(
      dateOfBirth.year,
      dateOfBirth.month,
      dateOfBirth.day,
    );
    return !normalizedDateOfBirth.isAfter(minimumDateOfBirth);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
