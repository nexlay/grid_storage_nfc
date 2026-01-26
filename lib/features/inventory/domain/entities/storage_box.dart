import 'package:isar/isar.dart';

part 'storage_box.g.dart';

@collection
class StorageBox {
  Id id = Isar.autoIncrement;

  late String itemName;
  late int quantity;
  late int threshold;
  late String hexColor;
  late String modelPath;
  late DateTime lastUsed;

  bool isSynced = false;
  String? remoteId;

  // Brak konstruktora StorageBox({required ...}) !!!

  StorageBox copyWith({
    Id? id,
    String? itemName,
    int? quantity,
    int? threshold,
    String? hexColor,
    String? modelPath,
    DateTime? lastUsed,
    bool? isSynced,
    String? remoteId,
  }) {
    return StorageBox()
      ..id = id ?? this.id
      ..itemName = itemName ?? this.itemName
      ..quantity = quantity ?? this.quantity
      ..threshold = threshold ?? this.threshold
      ..hexColor = hexColor ?? this.hexColor
      ..modelPath = modelPath ?? this.modelPath
      ..lastUsed = lastUsed ?? this.lastUsed
      ..isSynced = isSynced ?? this.isSynced
      ..remoteId = remoteId ?? this.remoteId;
  }
}
