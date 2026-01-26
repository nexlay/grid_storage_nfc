import 'package:isar/isar.dart';

part 'storage_box.g.dart';

@collection
class StorageBox {
  // FIX: Initialize with autoIncrement to prevent LateInitializationError
  Id id = Isar.autoIncrement;

  late String itemName;
  late int quantity;
  late int threshold;
  late String hexColor;
  late String modelPath;
  late DateTime lastUsed;
}
