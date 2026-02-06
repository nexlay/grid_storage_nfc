part of 'inventory_bloc.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

/// Żądanie załadowania listy wszystkich przedmiotów
class LoadAllItems extends InventoryEvent {
  const LoadAllItems();
}

/// Reset stanu do początkowego
class ResetInventory extends InventoryEvent {
  const ResetInventory();
}

/// Rozpoczęcie skanowania NFC (odczyt)
class ScanTagRequested extends InventoryEvent {
  const ScanTagRequested();
}

/// Przetworzenie ręcznie wpisanego lub zeskanowanego kodu (QR/Manual ID)
class ProcessScannedCode extends InventoryEvent {
  final String rawCode;

  const ProcessScannedCode(this.rawCode);

  @override
  List<Object?> get props => [rawCode];
}

/// Aktualizacja ilości
class UpdateQuantity extends InventoryEvent {
  final String boxId;
  final int newQuantity;

  const UpdateQuantity({
    required this.boxId,
    required this.newQuantity,
  });

  @override
  List<Object?> get props => [boxId, newQuantity];
}

/// Żądanie usunięcia pudełka
class DeleteBoxRequested extends InventoryEvent {
  final String boxId;

  const DeleteBoxRequested({required this.boxId});

  @override
  List<Object?> get props => [boxId];
}

/// Żądanie zapisu (utworzenie nowego lub edycja)
class WriteTagRequested extends InventoryEvent {
  final int? id; // null = nowy przedmiot
  final String name;
  final int quantity;
  final int threshold;
  final String color;
  final bool writeToNfc;
  final String? barcode; // Nowe pole: Kod (np. LOC-123...)
  final String? imagePath; // Nowe pole: Ścieżka do zdjęcia

  const WriteTagRequested({
    this.id,
    required this.name,
    required this.quantity,
    required this.threshold,
    required this.color,
    this.writeToNfc = true,
    this.barcode,
    this.imagePath,
  });

  @override
  List<Object?> get props =>
      [id, name, quantity, threshold, color, writeToNfc, barcode, imagePath];
}
