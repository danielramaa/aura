import 'package:flutter/material.dart';
import '../models/group.dart';

class HomeController extends ChangeNotifier {
  static const Color _defaultGroupColor = Color(0xFF378ADD);

  final List<Group> _groups = const [
    Group(
      name: 'Diabetes Tipo 2',
      lastMessage: 'User123: "Olá!"',
      time: '14:32',
      color: _defaultGroupColor,
      unreadCount: 2,
      isOnline: true,
      memberCount: 2400,
    ),
    Group(
      name: 'Hipertensão',
      lastMessage: 'Anonymous: "Alguém tem dicas para controlar a pressão?"',
      time: '11:05',
      color: _defaultGroupColor,
      unreadCount: 0,
      isOnline: false,
      memberCount: 1100,
    ),
    Group(
      name: 'Asma',
      lastMessage: 'Sem novas mensagens',
      time: 'Mon',
      color: _defaultGroupColor,
      unreadCount: 5,
      isOnline: false,
      memberCount: 890,
    ),
  ];

  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Group> get groups => List.unmodifiable(
    _groups.where(
      (g) => g.name.toLowerCase().contains(_searchQuery.toLowerCase()),
    ),
  );
}
