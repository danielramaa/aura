import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../controllers/main_controller.dart';
import '../controllers/profile_controller.dart';
import '../services/group_service.dart';
import '../services/identity_service.dart';
import 'home_screen.dart';
import 'find_groups_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';

class MainScreen extends StatelessWidget {
  final MainController mainController;
  final HomeController homeController;
  final ProfileController? profileController;
  final GroupService? findGroupsService;
  final IdentityService? findGroupsIdentityService;
  final FirebaseAuth? findGroupsAuth;

  const MainScreen({
    super.key,
    required this.mainController,
    required this.homeController,
    this.profileController,
    this.findGroupsService,
    this.findGroupsIdentityService,
    this.findGroupsAuth,
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
          FindGroupsScreen(
            groupService: findGroupsService,
            identityService: findGroupsIdentityService,
            auth: findGroupsAuth,
          ),
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
                label: 'Minhas comunidades',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Encontrar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_outlined),
                label: 'Notificações',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}
