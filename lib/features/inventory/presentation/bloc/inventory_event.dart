part of 'inventory_bloc.dart';

abstract class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object> get props => [];
}

class ScanTagRequested extends InventoryEvent {
  const ScanTagRequested();
}

class UpdateQuantity extends InventoryEvent {
  final String boxId;
  final int newQuantity;

  const UpdateQuantity({required this.boxId, required this.newQuantity});

  @override
  List<Object> get props => [boxId, newQuantity];
}

class LoadInventory extends InventoryEvent {
  const LoadInventory();
}

// New event
class LoadAllItems extends InventoryEvent {
  const LoadAllItems();
}

class ResetInventory extends InventoryEvent {
  const ResetInventory();
}

class WriteTagRequested extends InventoryEvent {
  final String? id; // Optional ID for editing existing items
  final String name;
  final String description;
  final int quantity;
  final int threshold;
  final String color;

  const WriteTagRequested({
    this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.threshold,
    required this.color,
  });

  @override
  List<Object> get props => [
        id ?? '',
        name,
        description,
        quantity,
        threshold,
        color,
      ];
}

// Renamed event
class DeleteBoxRequested extends InventoryEvent {
  final String boxId;

  const DeleteBoxRequested({required this.boxId});

  @override
  List<Object> get props => [boxId];
}
