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

class InventoryLoaded extends InventoryState {
  final StorageBox box;
  final bool isLowStock;
  final String? message;

  const InventoryLoaded({
    required this.box,
    this.isLowStock = false,
    this.message,
  });

  @override
  List<Object?> get props => [box, isLowStock, message];
}

class InventoryError extends InventoryState {
  final String message;

  const InventoryError(this.message);

  @override
  List<Object> get props => [message];
}