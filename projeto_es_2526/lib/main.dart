import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'controllers/home_controller.dart';
import 'controllers/main_controller.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reaccept_terms_screen.dart';
import 'services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final authService = AuthService();
    final stayLoggedIn = await authService.getStayLoggedIn();
    if (!stayLoggedIn && authService.currentUser != null) {
      await authService.logout();
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text('This app is only supported on Android and iOS.'),
          ),
        ),
      );
    }
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  final Stream<User?>? authStream;
  final MainController? mainController;
  final HomeController? homeController;
  final AuthService? authService;

  const AuthGate({
    super.key,
    this.authStream,
    this.mainController,
    this.homeController,
    this.authService,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStream;
  late final AuthService _authService = widget.authService ?? AuthService();
  late final MainController _mainController;
  HomeController? _homeController;
  String? _currentUserId;
  late final bool _ownsMainController;
  late final bool _ownsHomeController;

  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _notifUserId;

  @override
  void initState() {
    super.initState();
    _authStream = widget.authStream ?? FirebaseAuth.instance.authStateChanges();
    _ownsMainController = widget.mainController == null;
    _ownsHomeController = widget.homeController == null;
    _mainController = widget.mainController ?? MainController();
    _setupPushNotifications().catchError((_) {});
  }

  Future<void> _setupPushNotifications() async {
    if (kIsWeb) return;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _authStateSubscription = _authStream.listen((User? user) async {
        if (user != null) {
          _notifUserId = user.uid;
          final token = await messaging.getToken();
          if (token != null) {
            await _saveDeviceToken(user.uid, token);
          }
          _tokenRefreshSubscription?.cancel();
          _tokenRefreshSubscription = messaging.onTokenRefresh.listen((
            newToken,
          ) {
            _saveDeviceToken(user.uid, newToken);
          });
        } else {
          if (_notifUserId != null) {
            await _clearDeviceToken(_notifUserId!);
            _notifUserId = null;
          }
          _tokenRefreshSubscription?.cancel();
          _tokenRefreshSubscription = null;
        }
      });
    }
  }

  Future<void> _saveDeviceToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<void> _clearDeviceToken(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    if (_ownsMainController) _mainController.dispose();
    if (_ownsHomeController) _homeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          if (_homeController == null || _currentUserId != uid) {
            if (_ownsHomeController) _homeController?.dispose();
            _currentUserId = uid;
            _homeController =
                widget.homeController ?? HomeController(userId: uid);
          }
          return LegalAcceptanceGate(
            authService: _authService,
            userId: uid,
            child: MainScreen(
              mainController: _mainController,
              homeController: _homeController!,
            ),
          );
        }
        if (_ownsHomeController) {
          _homeController?.dispose();
          _homeController = null;
        }
        _currentUserId = null;
        return const LoginScreen();
      },
    );
  }
}

/// Gates an authenticated user's access to [child] until their stored legal
/// acceptance matches the current document versions. When it's outdated the
/// user must re-accept to continue or decline (which logs them out).
class LegalAcceptanceGate extends StatefulWidget {
  final AuthService authService;
  final String userId;
  final Widget child;

  const LegalAcceptanceGate({
    super.key,
    required this.authService,
    required this.userId,
    required this.child,
  });

  @override
  State<LegalAcceptanceGate> createState() => _LegalAcceptanceGateState();
}

class _LegalAcceptanceGateState extends State<LegalAcceptanceGate> {
  late Future<bool> _needsReacceptance;

  @override
  void initState() {
    super.initState();
    _needsReacceptance = widget.authService.needsLegalReacceptance(
      widget.userId,
    );
  }

  @override
  void didUpdateWidget(covariant LegalAcceptanceGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _needsReacceptance = widget.authService.needsLegalReacceptance(
        widget.userId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _needsReacceptance,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Fail open on read errors so a transient Firestore failure can't lock
        // an already-authenticated user out of the app.
        if (snapshot.data == true) {
          return ReacceptTermsScreen(
            onAccept: () async {
              await widget.authService.acceptCurrentLegalDocuments(
                widget.userId,
              );
              if (mounted) {
                setState(() => _needsReacceptance = Future.value(false));
              }
            },
            onDecline: () => widget.authService.logout(),
          );
        }
        return widget.child;
      },
    );
  }
}
