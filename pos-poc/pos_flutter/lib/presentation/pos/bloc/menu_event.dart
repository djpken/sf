import 'package:equatable/equatable.dart';

abstract class MenuEvent extends Equatable {
  const MenuEvent();

  @override
  List<Object?> get props => [];
}

class LoadMenu extends MenuEvent {
  const LoadMenu();
}

class SelectCategory extends MenuEvent {
  final String categoryId;
  const SelectCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}
