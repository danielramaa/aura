import 'package:flutter/material.dart';
import 'controllers/home_controller.dart';
import 'controllers/main_controller.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScreen(
        mainController: MainController(),
        homeController: HomeController(),
      ),
    );
  }
}
