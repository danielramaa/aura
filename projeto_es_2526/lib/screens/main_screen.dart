import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/profile_controller.dart';
import 'home_screen.dart';
import 'find_groups_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';

class MainScreen extends StatelessWidget {
  final MainController mainController;
  final HomeController homeController;
  final ProfileController? profileController;

  const MainScreen({
    super.key,
    required this.mainController,
    required this.homeController,
    this.profileController,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: mainController,
      builder: (context, _) {
        final screens = [
          HomeScreen(
            controller: homeController,
            onFindGroups: () => mainController.navigateTo(1),
          ),
          const FindGroupsScreen(),
          const NotificationScreen(),
          ProfileScreen(controller: profileController),
        ];

        return Scaffold(
          backgroundColor: Colors.white,
          body: screens[mainController.currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: mainController.currentIndex,
            onTap: mainController.navigateTo,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF185FA5),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: 'My Groups',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Find Groups',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                label: 'Notifications',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
