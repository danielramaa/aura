import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../services/group_service.dart';

class HomeController extends ChangeNotifier {
  final GroupService _service;
  late final StreamSubscription<List<Group>> _subscription;

  List<Group> _groups = const [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _error;

  HomeController({GroupService? service})
      : _service = service ?? GroupService() {
    _subscription = _service.streamGroups().listen(
      (groups) {
        _groups = groups;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _isLoading = false;
        _error = 'Failed to load groups.';
        notifyListeners();
      },
    );
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
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

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
