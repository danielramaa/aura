import 'package:flutter/material.dart';
import '../models/group.dart';

class HomeController extends ChangeNotifier {
  static const Color _defaultGroupColor = Color(0xFF378ADD);

  final List<Group> _groups = const [
    Group(
      id: 'diabetes_tipo_2',
      name: 'Diabetes Tipo 2',
      description: 'Grupo dedicado a compartilhar receitas, rotinas e apoio mútuo para o controle da Diabetes Tipo 2.',
      memberCount: 2400,
      color: _defaultGroupColor,
    ),
    Group(
      id: 'hipertensao',
      name: 'Hipertensão',
      description: 'Espaço seguro para debatermos sobre controle de pressão, dicas de exercícios e redução de sódio no dia a dia.',
      memberCount: 1100,
      color: _defaultGroupColor,
    ),
    Group(
      id: 'asma',
      name: 'Asma',
      description: 'Comunidade de apoio para pessoas com asma. Troque experiências sobre tratamentos, gatilhos e qualidade de vida.',
      memberCount: 890,
      color: _defaultGroupColor,
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
