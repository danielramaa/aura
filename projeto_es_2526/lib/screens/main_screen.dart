import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';
import 'home_screen.dart';
import 'find_groups_screen.dart';

class MainScreen extends StatelessWidget {
  final MainController mainController;
  final HomeController homeController;

  const MainScreen({
    super.key,
    required this.mainController,
    required this.homeController,
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
          const Center(child: Text('Notifications')),
          const Center(child: Text('Profile')),
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
              BottomNavigationBarItem(icon: Icon(Icons.group), label: 'My Groups'),
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
