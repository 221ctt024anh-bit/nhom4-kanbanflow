import 'package:hive_flutter/hive_flutter.dart';

class HiveHelper {
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters if using TypeAdapters,
    // but for simplicity we'll use Map<String, dynamic> in boxes.

    await Hive.openBox('boards');
    await Hive.openBox('columns');
    await Hive.openBox('tasks');
  }
}
