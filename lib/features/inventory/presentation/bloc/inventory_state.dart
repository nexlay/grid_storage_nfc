part of 'inventory_bloc.dart';

abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => [];
}

class InventoryInitial extends InventoryState {
  const InventoryInitial();
}

class InventoryLoading extends InventoryState {
  const InventoryLoading();
}

/// Stan: Pojedynczy przedmiot załadowany (np. po skanie lub ręcznym wyborze)
class InventoryLoaded extends InventoryState {
  final StorageBox box;
  final bool isLowStock;
  final String? message;

  const InventoryLoaded({
    required this.box,
    required this.isLowStock,
    this.message,
  });

  @override
  List<Object?> get props => [box, isLowStock, message];
}

/// Stan: Lista przedmiotów załadowana (dla ekranu All Items)
class InventoryListLoaded extends InventoryState {
  final List<StorageBox> boxes;

  const InventoryListLoaded({required this.boxes});

  @override
  List<Object?> get props => [boxes];
}

/// Stan: Błąd
class InventoryError extends InventoryState {
  final String message;
  final String? scannedCode; // Kod, którego nie znaleziono w bazie

  const InventoryError(this.message, {this.scannedCode});

  @override
  List<Object?> get props => [message, scannedCode];
}
