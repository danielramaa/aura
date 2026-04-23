import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'controllers/home_controller.dart';
import 'controllers/main_controller.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  final Stream<User?>? authStream;
  final MainController? mainController;
  final HomeController? homeController;

  const AuthGate({
    super.key,
    this.authStream,
    this.mainController,
    this.homeController,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStream;
  late final MainController _mainController;
  HomeController? _homeController;
  late final bool _ownsControllers;

  @override
  void initState() {
    super.initState();
    _authStream = widget.authStream ?? FirebaseAuth.instance.authStateChanges();
    _ownsControllers = widget.mainController == null;
    _mainController = widget.mainController ?? MainController();
  }

  @override
  void dispose() {
    if (_ownsControllers) {
      _mainController.dispose();
      _homeController?.dispose();
    }
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
          _homeController ??= widget.homeController ?? HomeController();
          return MainScreen(
            mainController: _mainController,
            homeController: _homeController!,
          );
        }
        return const LoginScreen();
      },
    );
  }
}
