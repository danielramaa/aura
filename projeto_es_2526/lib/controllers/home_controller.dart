import 'package:flutter/material.dart';
import '../models/group.dart';

class HomeController extends ChangeNotifier {
  static const Color _defaultGroupColor = Color(0xFF378ADD);

  final List<Group> _groups = const [
    Group(
      id: 'diabetes_tipo_2',
      name: 'Diabetes Tipo 2',
      lastMessage: 'User123: "Olá!"',
      time: '14:32',
      color: _defaultGroupColor,
      unreadCount: 2,
      isOnline: true,
      memberCount: 2400,
      description: 'Grupo dedicado a compartilhar receitas, rotinas e apoio mútuo para o controle da Diabetes Tipo 2.',
    ),
    Group(
      id: 'hipertensao',
      name: 'Hipertensão',
      lastMessage: 'Anonymous: "Alguém tem dicas para controlar a pressão?"',
      time: '11:05',
      color: _defaultGroupColor,
      unreadCount: 0,
      isOnline: false,
      memberCount: 1100,
      description: 'Espaço seguro para debatermos sobre controle de pressão, dicas de exercícios e redução de sódio no dia a dia.',
    ),
    Group(
      id: 'asma',
      name: 'Asma',
      lastMessage: 'Sem novas mensagens',
      time: 'Mon',
      color: _defaultGroupColor,
      unreadCount: 5,
      isOnline: false,
      memberCount: 890,
      description: 'Comunidade de apoio para pessoas com asma. Troque experiências sobre tratamentos, gatilhos e qualidade de vida.',
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
