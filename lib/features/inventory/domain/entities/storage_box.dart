import 'package:isar/isar.dart';

part 'storage_box.g.dart';

@collection
class StorageBox {
  Id id = Isar.autoIncrement; // Lokalne ID (Isar)

  late String itemName;
  late int quantity;
  late int threshold;
  late String hexColor;
  late String modelPath;
  late DateTime lastUsed;
  String? barcode;

  bool isSynced = false;
  String? remoteId; // To będzie ID z PostgreSQL (jako String)

  // Konstruktor domyślny
  StorageBox();

  // --- NOWOŚĆ: Metody do komunikacji z API ---

  // 1. Zamiana obiektu na JSON (do wysyłki na serwer)
  Map<String, dynamic> toJson() {
    return {
      // Klucze muszą pasować do nazw kolumn w bazie SQL (snake_case)
      'item_name': itemName,
      'quantity': quantity,
      'threshold': threshold,
      'hex_color': hexColor,
      'model_path': modelPath,
      'last_used': lastUsed.toIso8601String(),
      'barcode': barcode,
    };
  }

  // 2. Tworzenie obiektu z JSON (z serwera)
  factory StorageBox.fromJson(Map<String, dynamic> json) {
    return StorageBox()
      ..remoteId = json['id'].toString() // Mapujemy ID z bazy na remoteId
      ..itemName = json['item_name'] ?? ''
      ..quantity = json['quantity'] ?? 0
      ..threshold = json['threshold'] ?? 0
      ..hexColor = json['hex_color'] ?? '#FFFFFF'
      ..modelPath = json['model_path'] ?? ''
      ..lastUsed = DateTime.tryParse(json['last_used'] ?? '') ?? DateTime.now()
      ..isSynced = true // Skoro przyszło z serwera, to jest zsynchronizowane
      ..barcode = json['barcode'];
  }

  // Twoja metoda copyWith (pozostaje bez zmian, skróciłem dla czytelności tutaj)
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
    String? barcode,
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
      ..remoteId = remoteId ?? this.remoteId
      ..barcode = barcode ?? this.barcode;
  }
}
