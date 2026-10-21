import 'package:flutter/services.dart' show appFlavor;

/// Build flavor, set by `flutter run --flavor <name>`.
enum AppFlavor {
  operators,
  staff;

  static AppFlavor get current =>
      appFlavor == 'staff' ? AppFlavor.staff : AppFlavor.operators;

  bool get isStaff => this == AppFlavor.staff;
  bool get isOperators => this == AppFlavor.operators;

  String get title => isStaff ? 'TMS Staff' : 'TMS Operadores';
}
