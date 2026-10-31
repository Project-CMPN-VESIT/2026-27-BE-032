import 'package:flutter/material.dart';

/// Global bottom navigation state provider.
/// All screens call [setIndex] in initState to keep the active icon in sync.
class NavProvider with ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }
}
