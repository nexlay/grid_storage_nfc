# Project Status

This document summarizes the analysis of the `grid_storage_nfc` Flutter project.

## Project Architecture

The project follows the Clean Architecture pattern, separating the code into three main layers: `data`, `domain`, and `presentation`. This is done for the `inventory` feature.

## Directory Structure

### `lib`

The main directory for the Dart code.

- **`main.dart`**: The entry point of the application.
- **`injection_container.dart`**: Handles dependency injection, likely using `get_it`.

### `lib/core`

Contains code that is shared across multiple features.

- **`services/nfc_service.dart`**: Provides services for NFC tag reading and writing.
- **`theme/theme_cubit.dart`**: Manages the application's theme using the `bloc` library.

### `lib/features/inventory`

The main feature of the application, which is to manage the inventory.

#### `lib/features/inventory/domain`

The `domain` layer contains the business logic of the application.

- **`entities/storage_box.dart`**: Defines the `StorageBox` entity, which is the main business object.
- **`repositories/inventory_repository.dart`**: Defines the interface for the inventory repository.
- **`usecases`**: Contains the use cases for the inventory feature:
  - `delete_inventory_item.dart`
  - `get_inventory_item.dart`
  - `get_inventory_list.dart`
  - `get_last_used_item.dart`
  - `save_inventory_item.dart`

#### `lib/features/inventory/data`

The `data` layer is responsible for fetching data from different sources.

- **`datasources/inventory_local_data_source.dart`**: The implementation of the local data source for the inventory feature.
- **`repositories/inventory_repository_impl.dart`**: The implementation of the `InventoryRepository` interface.

#### `lib/features/inventory/presentation`

The `presentation` layer is responsible for the UI.

- **`bloc`**: Contains the `bloc` implementation for the inventory feature, which includes `inventory_bloc.dart`, `inventory_event.dart`, and `inventory_state.dart`.
- **`pages`**: Contains the different pages of the inventory feature:
  - `all_items_page.dart`
  - `inventory_page.dart`
  - `main_page.dart`
  - `settings_page.dart`
  - `setup_tag_screen.dart`
- **`widgets/box_3d_viewer.dart`**: A widget for viewing a 3D model of a box.

## Summary

The project is a Flutter application that uses NFC to manage a storage inventory. It is well-structured, following the Clean Architecture pattern, and uses the `bloc` library for state management. The main feature is the inventory management, which is split into `data`, `domain`, and `presentation` layers. The application also includes a 3D viewer for storage boxes.
