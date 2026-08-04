import 'package:flutter/foundation.dart';

class RecordsRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
