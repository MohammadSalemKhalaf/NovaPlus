import 'package:flutter/foundation.dart';

class StoreCubit extends ChangeNotifier {
  int? _currentStoreId;

  int? get currentStoreId => _currentStoreId;

  void setCurrentStore(int storeId) {
    if (_currentStoreId == storeId) {
      return;
    }
    _currentStoreId = storeId;
    notifyListeners();
  }

  void clearCurrentStore() {
    if (_currentStoreId == null) {
      return;
    }
    _currentStoreId = null;
    notifyListeners();
  }
}
