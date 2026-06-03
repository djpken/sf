import 'package:equatable/equatable.dart';

abstract class MenuMgmtEvent extends Equatable {
  const MenuMgmtEvent();

  @override
  List<Object?> get props => [];
}

class LoadMenuMgmt extends MenuMgmtEvent {
  const LoadMenuMgmt();
}

class SelectMgmtCategory extends MenuMgmtEvent {
  final String? categoryId;
  const SelectMgmtCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class CreateCategory extends MenuMgmtEvent {
  final String name;
  final String? description;
  final int displayOrder;

  const CreateCategory({
    required this.name,
    this.description,
    this.displayOrder = 0,
  });

  @override
  List<Object?> get props => [name, description, displayOrder];
}

class UpdateCategory extends MenuMgmtEvent {
  final String id;
  final String name;
  final String? description;
  final int displayOrder;
  final bool isActive;

  const UpdateCategory({
    required this.id,
    required this.name,
    this.description,
    required this.displayOrder,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, name, description, displayOrder, isActive];
}

class DeleteCategory extends MenuMgmtEvent {
  final String id;
  const DeleteCategory(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateItem extends MenuMgmtEvent {
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final bool isActive;
  final int displayOrder;

  const CreateItem({
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.isActive = true,
    this.displayOrder = 0,
  });

  @override
  List<Object?> get props =>
      [categoryId, name, description, price, isActive, displayOrder];
}

class UpdateItem extends MenuMgmtEvent {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final bool isActive;
  final int displayOrder;

  const UpdateItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    required this.isActive,
    required this.displayOrder,
  });

  @override
  List<Object?> get props =>
      [id, categoryId, name, description, price, isActive, displayOrder];
}

class DeleteItem extends MenuMgmtEvent {
  final String id;
  const DeleteItem(this.id);

  @override
  List<Object?> get props => [id];
}
